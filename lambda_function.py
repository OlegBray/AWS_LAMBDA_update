import json
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('imtech')
LOOK_FOR_ID = "oleg"

def lambda_handler(event, context):
    try:
        # Accept ID from input event, default to 'oleg' if not provided
        item_id = event.get("id", {LOOK_FOR_ID})
        
        response = table.get_item(Key={'id': item_id})
        
        if 'Item' in response:
            return {
                "statusCode": 200,
                "body": json.dumps(response['Item'])
            }
        else:
            return {
                "statusCode": 404,
                "error": f"No item found with id '{item_id}'"
            }

    except ClientError as e:
        return {
            "statusCode": 500,
            "error": e.response['Error']['Message']
        }
