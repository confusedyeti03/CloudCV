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
    GET /cv/{language}           - Redirect to PDF in S3
    GET /cv/{language}/pdf       - Redirect to PDF in S3
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

        # Redirect to PDF via CloudFront
        cloudfront_domain = "dq8zmgoscvrxi.cloudfront.net"
        pdf_url = f"https://{cloudfront_domain}/cv/cv_{language}.pdf"

        print(f"Redirecting to PDF via CloudFront: {pdf_url}")

        return {
            'statusCode': 303,
            'headers': {
                'Location': pdf_url,
                'Cache-Control': 'public, max-age=86400'
            },
            'body': '',
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
