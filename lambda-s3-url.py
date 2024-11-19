import os
import boto3
import json

s3 = boto3.client('s3')

def lambda_handler(event, context):
    bucket_name = os.environ['BUCKET_NAME']
    file_name = event['queryStringParameters']['filename']
    
    try:
        url = s3.generate_presigned_url(
            ClientMethod='get_object',
            Params={
                'Bucket': bucket_name,
                'Key': file_name
            },
            ExpiresIn=60 # URL expiry time in seconds
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({'url': url})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
