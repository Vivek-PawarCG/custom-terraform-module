import boto3
import os

def lambda_handler(event, context):
    ec2_client = boto3.client('ec2')
    instance_id = os.environ['INSTANCE_ID']

    response = ec2_client.start_instances(
        InstanceIds=[instance_id],
    )

    return response
