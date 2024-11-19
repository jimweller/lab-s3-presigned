import os
import json
import datetime
import boto3
from botocore.signers import CloudFrontSigner
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import hashes

secrets_manager_client = boto3.client('secretsmanager')
ssm_client = boto3.client('ssm')

cloudfront_domain = os.getenv("CLOUDFRONT_DOMAIN")                    # CloudFront domain
secret_name = os.getenv("SECRET_NAME")                                # Secret Manager name for private key
key_pair_id_parameter = os.getenv("KEY_PAIR_ID_PARAMETER")            # SSM Parameter Store path for Key Pair ID

def get_key_pair_id():
    response = ssm_client.get_parameter(Name=key_pair_id_parameter, WithDecryption=True)
    return response['Parameter']['Value']

def get_private_key():
    response = secrets_manager_client.get_secret_value(SecretId=secret_name)
    private_key_pem = response['SecretString']
    private_key = serialization.load_pem_private_key(
        private_key_pem.encode('utf-8'),
        password=None,
        backend=default_backend()
    )
    return private_key

def rsa_signer(message):
    private_key = get_private_key()
    return private_key.sign(
        message,
        padding.PKCS1v15(),
        hashes.SHA1()
    )

def lambda_handler(event, context):
    file_name = event['queryStringParameters']['filename']
    expire_time = datetime.datetime.utcnow() + datetime.timedelta(hours=1)

    key_pair_id = get_key_pair_id()
    signer = CloudFrontSigner(key_pair_id, rsa_signer)
    
    signed_url = signer.generate_presigned_url(
        url=f"https://{cloudfront_domain}/{file_name}",
        date_less_than=expire_time
    )

    return {
        "statusCode": 200,
        "body": json.dumps({"url": signed_url}),
        "headers": {"Content-Type": "application/json"}
    }
