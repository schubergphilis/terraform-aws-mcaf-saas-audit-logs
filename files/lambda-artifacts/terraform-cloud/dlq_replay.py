import boto3
import json
import os
import logging

# Setting up logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs = boto3.client('sqs')
MAIN_QUEUE_URL = os.environ['MAIN_QUEUE_URL']

def lambda_handler(event, context):
    for record in event['Records']:
        body = json.loads(record['body'])
        body['retry_count'] = 0 # Reset retry count for new processing
        
        sqs.send_message(
            QueueUrl=MAIN_QUEUE_URL,
            MessageBody=json.dumps(body),
            DelaySeconds=900  # Delay to avoid immediate reprocessing
        )
        logger.info(
            f'Replayed DLQ message for {body['operation']} page={body['page']} to main queue with delay seconds of 900.'
        )
