import json
import boto3
from botocore.exceptions import ClientError
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('imtech')
LOOK_FOR_ID = "oleg"  # Default value to search for if no 'id' is provided

# Helper function to convert DynamoDB Decimal values to native Python types
def convert_decimal(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    elif isinstance(obj, dict):
        return {k: convert_decimal(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [convert_decimal(i) for i in obj]
    return obj

def lambda_handler(event, context):
    try:
        # Accept ID from input event, default to 'oleg' if not provided
        item_id = event.get("id", LOOK_FOR_ID)  # Use string, not a set
        
        response = table.get_item(Key={'id': item_id})
        
        if 'Item' in response:
            # Convert Decimal values to float before serializing
            return {
                "statusCode": 200,
                "body": json.dumps(convert_decimal(response['Item']))
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
