import boto3
import compress_json
import datetime
import json
import logging
import os
import random
import requests
from botocore.exceptions import BotoCoreError, ClientError

# Set up logger
logger = logging.getLogger()
logger.setLevel(logging.getLevelName(os.environ.get('LOG_LEVEL', 'INFO').upper()))

# Timeout settings for HTTP requests
REQUEST_TIMEOUT = 5  # seconds


def uniqueid():
    """Generate unique IDs starting from a random seed."""
    seed = random.getrandbits(32)
    while True:
        yield seed
        seed += 1


def fetch_token(secret_name):
    """Fetch the secret token from AWS Secrets Manager."""
    try:
        secrets_client = boto3.client('secretsmanager')
        secret_response = secrets_client.get_secret_value(SecretId=secret_name)
        return secret_response['SecretString']
    except (BotoCoreError, ClientError) as e:
        logger.error(f'Error fetching secret {secret_name}: {e}')
        raise


def fetch_pagination_data(url, headers, params):
    """Fetch pagination data from Terraform Cloud."""
    try:
        response = requests.get(url, headers=headers, params=params, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()
        return response.json()
    except requests.Timeout as e:
        logger.error(f'Timeout while getting audit events from {url}: {e}')
        raise
    except requests.RequestException as e:
        logger.error(f'Error fetching pagination data: {e}')
        return None


def upload_to_s3(file_name, bucket, bucket_prefix, audit_data, compress=True):
    """Upload audit data to S3."""
    logger.debug('Uploading audit logs to S3...')

    if compress:
        file_name = file_name + '.gz'

    file_path = os.path.join('/tmp', file_name)

    try:
        if compress:
            logger.debug(f'Compressing the audit data to {file_path}...')
            compress_json.dump(audit_data, file_path)
        else:
            with open(file_path, 'w') as outfile:
                json.dump(audit_data, outfile, indent=4)
    except IOError as e:
        logger.error(f'Error writing to file {file_path}: {e}')
        raise
    except compress_json.CompressJSONError as e:
        logger.error(f'Error compressing the file {file_path}: {e}')
        raise

    try:
        s3 = boto3.resource('s3')
        s3.meta.client.upload_file(file_path, bucket, os.path.join(bucket_prefix, file_name))
        logger.info(f'Uploaded file: {file_name}, to bucket: {bucket}, with path: {bucket_prefix}')
    except (BotoCoreError, ClientError) as e:
        logger.error(f'Error uploading file {file_name} to S3: {e}')
        raise


def send_sqs_message(queue_url, message_body):
    """Send a message to SQS."""

    sqs = boto3.client('sqs')
    try:
        sqs.send_message(QueueUrl=queue_url, MessageBody=json.dumps(message_body))
    except ClientError as e:
        logger.error(f'Error sending SQS message: {e}')
        raise


def send_sqs_batch_messages(queue_url, messages):
    """Send a batch of messages to SQS."""

    sqs = boto3.client('sqs')
    try:
        sqs.send_message_batch(QueueUrl=queue_url, Entries=messages)
    except ClientError as e:
        logger.error(f'Error sending SQS batch messages: {e}')
        raise


def handler(event, context):
    """Main function to get and store audit events from Terraform Cloud."""

    # Retrieve environment variables
    try:
        secret_name = os.environ['SECRET_NAME']
        token = fetch_token(secret_name)
        bucket = os.environ['BUCKET_NAME']
        bucket_prefix = os.environ['BUCKET_PREFIX']
        audit_api_url = os.environ['AUDIT_API_URL']
        compress = os.environ.get('COMPRESS_AUDIT_LOGS', 'True').lower() == 'true'
        days_to_fetch = int(os.environ['DAYS_TO_FETCH'])
        queue_url = os.environ['QUEUE_URL']
    except KeyError as e:
        logger.error(f'Missing environment variable: {e}')
        raise

    headers = {'Content-Type': 'application/json', 'Authorization': f'Bearer {token}'}

    # Determine the date for the logs
    since = datetime.date.today() - datetime.timedelta(days=days_to_fetch)
    log_date = since.strftime('%Y-%m-%d')
    unique_sequence = uniqueid()

    # Check if the Lambda is triggered by a CloudWatch event
    if 'source' in event and event['source'] == 'aws.events':
        logger.debug('Lambda triggered by CloudWatch event')
        # Send the initial message to SQS to start the process
        message_body = {'log_date': log_date, 'page': 1, 'total_pages': 1, 'operation': 'extract_init'}
        send_sqs_message(queue_url, message_body)
        return 'Initial message sent'

    # Check if the Lambda is triggered by an SQS event
    if 'Records' in event:
        logger.debug('Lambda triggered by SQS event')
        message = event['Records'][0]
        body = json.loads(message['body'])
        log_date = body['log_date']
        page = body['page']
        total_pages = body['total_pages']
        operation = body['operation']

        # Handle initial extraction or continue extraction
        if operation in ['extract_init', 'extract_continue']:
            if operation == 'extract_init':
                logger.info('Starting extraction...')
                # Fetch the total number of pages to be processed
                params = {'since': log_date}
                data = fetch_pagination_data(audit_api_url, headers, params)
                if data:
                    total_pages = data['pagination']['total_pages']

            sqs_pages = []
            for index in range(9):
                if index + page <= total_pages:
                    sqs_pages.append(
                        {
                            'Id': str(next(unique_sequence)),
                            'MessageBody': json.dumps(
                                {'page': index + page, 'total_pages': total_pages, 'operation': 'extract', 'log_date': log_date}
                            ),
                        }
                    )

            # Schedule the next batch of pages for extraction if necessary
            if index + page < total_pages:
                sqs_pages.append(
                    {
                        'Id': str(next(unique_sequence)),
                        'MessageBody': json.dumps(
                            {'page': index + page + 1, 'total_pages': total_pages, 'operation': 'extract_continue', 'log_date': log_date}
                        ),
                    }
                )

            if sqs_pages:
                send_sqs_batch_messages(queue_url, sqs_pages)
                return 'Batch messages sent'

            return 'Nothing to continue'

        # Handle the extraction of audit data
        if operation == 'extract':
            logger.info(f'Extracting audit data for page {page}...')
            params = {'since': log_date, 'page[number]': page}
            data = fetch_pagination_data(audit_api_url, headers, params)
            if data:
                audit_data = data['data']
                if audit_data:
                    # Create a file name and upload the audit data to S3
                    file_name = f"{log_date}:{since.strftime('%Y%m%d-%H%M%S')}:{page}.json"
                    upload_to_s3(file_name, bucket, os.path.join(bucket_prefix, since.strftime('%Y%m%d')), audit_data, compress)
                    return 'File stored'

    return 'Nothing to store'
