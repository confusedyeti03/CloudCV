import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')

projects_table = dynamodb.Table(os.environ.get('DDB_PROJECTS_TABLE', 'lnoval-cv-projects-cache'))

def handler(event, context):
    """
    Lambda handler for projects API
    GET /projects              - Returns all projects
    GET /projects/{type}       - Returns projects by type
    """
    try:
        # Extract project type from path parameters (optional)
        path_params = event.get('pathParameters', {})
        project_type = path_params.get('type', None) if path_params else None

        if project_type:
            # Get specific project type
            response = projects_table.get_item(Key={'project_type': project_type})

            if 'Item' not in response:
                return {
                    'statusCode': 404,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'error': f'Project type "{project_type}" not found'})
                }

            projects = response['Item'].get('projects', [])
            count = len(projects)
            print(f"Projects retrieved for type: {project_type}, count: {count}")

        else:
            # Get all projects (scan entire table)
            response = projects_table.scan()
            all_projects = []

            for item in response.get('Items', []):
                all_projects.extend(item.get('projects', []))

            projects = all_projects
            count = len(projects)
            print(f"All projects retrieved, count: {count}")

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Cache-Control': 'public, max-age=3600'
            },
            'body': json.dumps({
                'count': count,
                'projects': projects
            })
        }

    except Exception as e:
        print(f"Error in projects_handler: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }
