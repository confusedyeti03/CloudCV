import json
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')

visits_table = dynamodb.Table(os.environ.get('DDB_VISITS_TABLE', 'example-cloudcv-visits'))

# Sort key reserved for the per-page aggregate counter item.
# It has no TTL so the accumulated count never expires.
COUNTER_SORT_KEY = 0


def handler(event, context):
    """
    Lambda handler for visit tracking
    POST /visits
    Body: { "page_id": "home" }
    Returns the accumulated visit_count for the page.
    Abuse control is handled by API Gateway throttling (see api-gateway.tf).
    No client IP or User-Agent is stored (GDPR: avoid retaining personal data).
    """
    try:
        # Parse request body
        body_str = event.get('body') or '{}'
        body = json.loads(body_str) if isinstance(body_str, str) else body_str

        page_id = body.get('page_id', 'unknown')

        # Increment the aggregate counter for this page (atomic ADD)
        response = visits_table.update_item(
            Key={
                'page_id': page_id,
                'timestamp': COUNTER_SORT_KEY
            },
            UpdateExpression='ADD visit_count :inc SET last_visit_at = :now',
            ExpressionAttributeValues={
                ':inc': 1,
                ':now': datetime.utcnow().isoformat()
            },
            ReturnValues='UPDATED_NEW'
        )

        visit_count = int(response['Attributes']['visit_count'])
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
                'visit_count': visit_count
            })
        }

    except Exception as e:
        print(f"Error in visit_counter: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }
