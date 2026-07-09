import json
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')

visits_table = dynamodb.Table(os.environ.get('DDB_VISITS_TABLE', 'example-cloudcv-visits'))
api_key = os.environ.get('API_KEY', '')

# Sort key reserved for the per-page aggregate counter item.
# It has no TTL so the accumulated count never expires.
COUNTER_SORT_KEY = 0


def handler(event, context):
    """
    Lambda handler for visit tracking
    POST /visits
    Headers: Authorization: Bearer <api-key> OR X-API-Key: <api-key>
    Body: { "page_id": "home" }
    Returns the accumulated visit_count for the page.
    """
    try:
        # FASE 5: Validate API key (skipped when API_KEY is not configured)
        headers = event.get('headers', {}) or {}
        auth_header = headers.get('authorization', '') or headers.get('Authorization', '')
        api_key_header = headers.get('x-api-key', '') or headers.get('X-API-Key', '')

        provided_key = None
        if auth_header.startswith('Bearer '):
            provided_key = auth_header[7:]
        elif api_key_header:
            provided_key = api_key_header

        if api_key and provided_key != api_key:
            print("Unauthorized visit tracking attempt")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Unauthorized. Invalid or missing API key.'})
            }

        # Parse request body
        body_str = event.get('body') or '{}'
        body = json.loads(body_str) if isinstance(body_str, str) else body_str

        page_id = body.get('page_id', 'unknown')
        user_agent = headers.get('user-agent', 'unknown')
        # HTTP API payload v2 exposes the client IP under requestContext.http
        source_ip = event.get('requestContext', {}).get('http', {}).get('sourceIp', 'unknown')

        # Increment the aggregate counter for this page (atomic ADD)
        response = visits_table.update_item(
            Key={
                'page_id': page_id,
                'timestamp': COUNTER_SORT_KEY
            },
            UpdateExpression='ADD visit_count :inc SET last_visit_at = :now, last_user_agent = :ua, last_source_ip = :ip',
            ExpressionAttributeValues={
                ':inc': 1,
                ':now': datetime.utcnow().isoformat(),
                ':ua': user_agent,
                ':ip': source_ip
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
