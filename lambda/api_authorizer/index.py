import json
import os

api_key = os.environ.get('API_KEY', 'default-api-key')

def handler(event, context):
    """
    API Key validator for CloudCV API
    Validates X-API-Key header against configured API key
    Returns 401 if API key is invalid or missing
    """
    try:
        # Extract API key from Authorization header or X-API-Key
        auth_header = event.get('headers', {}).get('authorization', '')
        api_key_header = event.get('headers', {}).get('x-api-key', '')

        # Support "Bearer <api-key>" format
        if auth_header.startswith('Bearer '):
            provided_key = auth_header[7:]
        else:
            provided_key = api_key_header

        # Validate API key
        if not provided_key or provided_key != api_key:
            print(f"Unauthorized API access attempt")
            return {
                'statusCode': 401,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Unauthorized. Invalid or missing API key.'})
            }

        # API key is valid
        print(f"API key validated successfully")
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'authorized': True})
        }

    except Exception as e:
        print(f"Error in API authorizer: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }
