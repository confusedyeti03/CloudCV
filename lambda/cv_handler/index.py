import json
import boto3
import os
from datetime import datetime, timedelta

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')

cv_table = dynamodb.Table(os.environ.get('DDB_CV_CACHE_TABLE', 'lnoval-cv-cv-cache'))
s3_bucket = os.environ.get('S3_BUCKET', 'lnoval-cv-assets')

def handler(event, context):
    """
    Lambda handler for CV API
    GET /cv/{language}           - Returns CV as HTML
    GET /cv/{language}/pdf       - Returns CV as PDF
    """
    try:
        # Extract language from path parameters
        path_params = event.get('pathParameters', {})
        language = path_params.get('language', 'en') if path_params else 'en'

        # Validate language
        if language not in ['ca', 'es', 'en']:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Invalid language. Must be ca, es, or en'})
            }

        # Check if PDF requested
        raw_path = event.get('rawPath', '')
        is_pdf = raw_path.endswith('/pdf')

        # Try to get CV from DynamoDB cache first
        try:
            cache_response = cv_table.get_item(Key={'language': language})

            if 'Item' in cache_response:
                cv_html = cache_response['Item'].get('content', '')
                print(f"CV retrieved from cache for language: {language}")
            else:
                # Not in cache, fetch from S3
                cv_html = fetch_cv_from_s3(language)

                # Cache in DynamoDB for 1 day
                expiration_time = int((datetime.now() + timedelta(days=1)).timestamp())
                cv_table.put_item(Item={
                    'language': language,
                    'content': cv_html,
                    'expiration_time': expiration_time,
                    'cached_at': int(datetime.now().timestamp())
                })
                print(f"CV cached for language: {language}")

        except Exception as e:
            print(f"Cache error: {str(e)}, fetching from S3")
            cv_html = fetch_cv_from_s3(language)

        # Prepare response
        if is_pdf:
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/pdf',
                    'Content-Disposition': f'attachment; filename="CV-Lluis-Noval-{language}.pdf"'
                },
                'body': cv_html,
                'isBase64Encoded': False
            }
        else:
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'text/html; charset=utf-8',
                    'Cache-Control': 'public, max-age=3600'
                },
                'body': cv_html,
                'isBase64Encoded': False
            }

    except Exception as e:
        print(f"Error in cv_handler: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }

def fetch_cv_from_s3(language):
    """Fetch CV HTML from S3 bucket"""
    try:
        key = f'cv/cv-{language}.html'
        s3_response = s3.get_object(Bucket=s3_bucket, Key=key)
        cv_html = s3_response['Body'].read().decode('utf-8')
        print(f"CV fetched from S3: {key}")
        return cv_html
    except s3.exceptions.NoSuchKey:
        raise Exception(f"CV file not found in S3: cv-{language}.html")
    except Exception as e:
        raise Exception(f"Failed to fetch CV from S3: {str(e)}")
