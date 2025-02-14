import boto3
import compress_json
import datetime
import json
import logging
import os
import requests
from botocore.exceptions import BotoCoreError, ClientError

# Set up logger
logger = logging.getLogger()
logger.setLevel(logging.getLevelName(os.environ.get("LOG_LEVEL", "INFO").upper()))

# Timeout settings for HTTP requests
REQUEST_TIMEOUT = 5  # seconds


def fetch_token(secret_name):
    """Fetch the secret token from AWS Secrets Manager."""
    try:
        secrets_client = boto3.client("secretsmanager")
        secret_response = secrets_client.get_secret_value(SecretId=secret_name)
        return secret_response["SecretString"]
    except (BotoCoreError, ClientError) as e:
        logger.error(f"Error fetching secret {secret_name}: {e}")
        raise


def get_audit_events(url, headers, params):
    """Retrieve audit events from Okta API."""
    try:
        logger.debug(f"Fetching audit events from {url} with params: {params}")
        response = requests.get(
            url, headers=headers, params=params, timeout=REQUEST_TIMEOUT
        )
        response.raise_for_status()
        return response.json()
    except requests.Timeout as e:
        logger.error(f"Timeout while getting audit events from {url}: {e}")
        raise
    except requests.RequestException as e:
        logger.error(f"Error getting audit events from {url}: {e}")
        raise


def upload_to_s3(file_name, bucket, bucket_prefix, audit_data, compress=True):
    """Upload audit data to S3."""
    logger.debug("Uploading audit logs to S3...")

    if compress:
        file_name = file_name + ".gz"

    file_path = os.path.join("/tmp", file_name)

    try:
        if compress:
            logger.debug(f"Compressing the audit data to {file_path}...")
            compress_json.dump(audit_data, file_path)
        else:
            with open(file_path, "w") as outfile:
                json.dump(audit_data, outfile, indent=4)
    except IOError as e:
        logger.error(f"Error writing to file {file_path}: {e}")
        raise
    except compress_json.CompressJSONError as e:
        logger.error(f"Error compressing the file {file_path}: {e}")
        raise

    try:
        s3 = boto3.resource("s3")
        s3.meta.client.upload_file(
            file_path, bucket, os.path.join(bucket_prefix, file_name)
        )
        logger.info(
            f"Uploaded file: {file_name}, to bucket: {bucket}, with path: {bucket_prefix}"
        )
    except (BotoCoreError, ClientError) as e:
        logger.error(f"Error uploading file {file_name} to S3: {e}")
        raise


def handler(event, context):
    """Main function to get and store audit events from Okta."""
    try:
        secret_name = os.environ["SECRET_NAME"]
        token = fetch_token(secret_name)
        bucket = os.environ["BUCKET_NAME"]
        bucket_prefix = os.environ["BUCKET_PREFIX"]
        audit_api_url = os.environ["AUDIT_API_URL"]
        compress = os.environ.get("COMPRESS_AUDIT_LOGS", "True").lower() == "true"
        days_to_fetch = int(os.environ["DAYS_TO_FETCH"])
    except KeyError as e:
        logger.error(f"Missing environment variable: {e}")
        raise

    headers = {"Authorization": f"SSWS {token}"}

    today = datetime.date.today()
    created = today - datetime.timedelta(days=days_to_fetch)
    created_after = created.strftime("%Y-%m-%dT00:00:00.000Z")
    created_before = today.strftime("%Y-%m-%dT23:59:59.999Z")

    params = {"since": created_after, "until": created_before, "limit": 1000}
    logger.info(
        f"Collecting audit events between {created_after} and {created_before}..."
    )

    try:
        logs = get_audit_events(f"{audit_api_url}/api/v1/logs", headers, params)
        logger.debug(f"Okta logs: {logs}")

        if not logs:
            return "No logs retrieved."

        file_name = created.strftime("%Y%m%d") + ".json"
        upload_to_s3(file_name, bucket, bucket_prefix, logs, compress)
    except Exception as e:
        logger.error(f"An error occurred during the handler execution: {e}")
        raise

    return "File stored"
