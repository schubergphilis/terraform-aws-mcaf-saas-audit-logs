import boto3
import compress_json
import datetime
import json
import logging
import os
import requests
from botocore.exceptions import BotoCoreError, ClientError

# Setting up logger
logger = logging.getLogger()
logger.setLevel(logging.getLevelName(os.environ.get('LOG_LEVEL', 'INFO').upper()))

# Timeout settings for HTTP requests
REQUEST_TIMEOUT = 5  # seconds


def fetch_token(secret_name):
    """Fetch the secret token from AWS Secrets Manager."""
    try:
        secrets_client = boto3.client('secretsmanager')
        secret_response = secrets_client.get_secret_value(SecretId=secret_name)
        return secret_response['SecretString']
    except (BotoCoreError, ClientError) as e:
        logger.error(f'Error fetching secret {secret_name}: {e}')
        raise


def get_all_groups(headers):
    """Retrieve all groups from GitLab API."""
    url = f"{os.environ['AUDIT_API_URL']}/groups"
    groups = []
    try:
        response = requests.get(url, headers=headers, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()
        groups = response.json()
    except requests.RequestException as e:
        logger.error(f'Error getting groups from {url}: {e}')
        raise
    return groups


def get_all_projects(headers, group_id):
    """Retrieve all projects for a given group from GitLab API."""
    url = f"{os.environ['AUDIT_API_URL']}/groups/{group_id}/projects"
    projects = []
    try:
        response = requests.get(url, headers=headers, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()
        projects = response.json()
    except requests.RequestException as e:
        logger.error(f'Error getting projects from {url} for group {group_id}: {e}')
        raise
    return projects


def get_audit_events(url, headers, params):
    """Retrieve audit events from GitLab API."""
    try:
        logger.debug(f'Fetching audit events from {url} with params: {params}')
        response = requests.get(url, headers=headers, params=params, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()
        return response.json()
    except requests.Timeout as e:
        logger.error(f'Timeout while getting audit events from {url}: {e}')
        raise
    except requests.RequestException as e:
        logger.error(f'Error getting audit events from {url}: {e}')
        raise


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


def handler(event, context):
    """Main function to get and store audit events for all groups and projects."""
    try:
        secret_name = os.environ['SECRET_NAME']
        token = fetch_token(secret_name)
        bucket = os.environ['BUCKET_NAME']
        bucket_prefix = os.environ['BUCKET_PREFIX']
        audit_api_url = os.environ['AUDIT_API_URL']
        compress = os.environ.get('COMPRESS_AUDIT_LOGS', 'True').lower() == 'true'
        days_to_fetch = int(os.environ['DAYS_TO_FETCH'])
    except KeyError as e:
        logger.error(f'Missing environment variable: {e}')
        raise

    headers = {'PRIVATE-TOKEN': token}

    today = datetime.date.today()
    created = today - datetime.timedelta(days=days_to_fetch)
    created_after = created.strftime('%Y-%m-%dT00:00:00.000Z')
    created_before = today.strftime('%Y-%m-%dT23:59:59.999Z')
    params = {'created_after': created_after, 'created_before': created_before}

    logger.info(f'Collecting audit events between {created_after} and {created_before}...')

    try:
        if audit_api_url != 'https://gitlab.com/api/v4':
            # Fetch instance audit logs for self-hosted GitLab instances
            instance_audit_url = f'{audit_api_url}/audit_events'
            instance_audit_events = get_audit_events(instance_audit_url, headers, params)

            # Upload instance audit logs to S3
            instance_file_name = created.strftime('%Y%m%d') + '_instance_audit_logs.json'
            upload_to_s3(instance_file_name, bucket, bucket_prefix, instance_audit_events, compress)

        # Fetch all groups
        groups = get_all_groups(headers)
        logger.debug(f'Number of groups found: {len(groups)}')
        group_audit_events = []
        project_audit_events = []

        for group in groups:
            group_id = group['id']
            group_url = f'{audit_api_url}/groups/{group_id}/audit_events'
            logger.debug(f'Fetching audit events for group {group_id}')
            group_events = get_audit_events(group_url, headers, params)
            group_audit_events.extend(group_events)

            # Fetch all projects for each group
            projects = get_all_projects(headers, group_id)
            logger.debug(f'Number of projects found for group {group_id}: {len(projects)}')

            for project in projects:
                project_id = project['id']
                project_url = f'{audit_api_url}/projects/{project_id}/audit_events'
                logger.debug(f'Fetching audit events for project {project_id}')
                project_events = get_audit_events(project_url, headers, params)
                project_audit_events.extend(project_events)

        # Upload group audit events to S3
        group_file_name = created.strftime('%Y%m%d') + '_group_audit_logs.json'
        upload_to_s3(group_file_name, bucket, bucket_prefix, group_audit_events, compress)

        # Upload project audit events to S3
        project_file_name = created.strftime('%Y%m%d') + '_project_audit_logs.json'
        upload_to_s3(project_file_name, bucket, bucket_prefix, project_audit_events, compress)
    except Exception as e:
        logger.error(f'An error occurred during the handler execution: {e}')
        raise

    return 'Files stored'
