import json
import boto3
import os
from datetime import datetime, timedelta

dynamodb = boto3.resource('dynamodb')

visits_table = dynamodb.Table(os.environ.get('DDB_VISITS_TABLE', 'lnoval-cv-visits'))

def handler(event, context):
    """
    Lambda handler for visit tracking
    POST /visits
    Body: { "page_id": "portfolio", "metadata": {...} }
    """
    try:
        # Parse request body
        body_str = event.get('body', '{}')
        if isinstance(body_str, str):
            body = json.loads(body_str)
        else:
            body = body_str

        page_id = body.get('page_id', 'unknown')
        user_agent = event.get('headers', {}).get('user-agent', 'unknown')
        source_ip = event.get('requestContext', {}).get('identity', {}).get('sourceIp', 'unknown')

        # Get current timestamp
        timestamp = int(datetime.now().timestamp())

        # Calculate TTL: 90 days from now
        ttl_timestamp = int((datetime.now() + timedelta(days=90)).timestamp())

        # Update visit counter in DynamoDB
        response = visits_table.update_item(
            Key={
                'page_id': page_id,
                'timestamp': timestamp
            },
            UpdateExpression='ADD visit_count :inc SET expiration_time = :ttl, last_user_agent = :ua, last_source_ip = :ip',
            ExpressionAttributeValues={
                ':inc': 1,
                ':ttl': ttl_timestamp,
                ':ua': user_agent,
                ':ip': source_ip
            },
            ReturnValues='UPDATED_NEW'
        )

        visit_count = response['Attributes'].get('visit_count', 1)
        print(f"Visit recorded for page: {page_id}, count: {visit_count}")

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Cache-Control': 'no-cache'
            },
            'body': json.dumps({
                'message': 'Visit recorded',
                'page_id': page_id,
                'visit_count': int(visit_count) if visit_count else 1
            })
        }

    except Exception as e:
        print(f"Error in visit_counter: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }
