import os
import uuid
import json
import boto3
from boto3.exceptions import BotoCoreError, ClientError 
from datetime import datetime,timezone
from pydantic import BaseModel
from fastapi import FastAPI, Request, HTTPException
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_client import Counter
app = FastAPI(title="ZeroCost-InfraProject", description="A FastAPI application for ZeroCost-InfraProject", version="1.0.0")

# Here we are using Instrumentator so that we don't have to manually create metrics for every endpoint.
Instrumentator().instrument(app).expose(app)

ORDER_PROCESSED = Counter(
"order_processed_total","Total Number of Orders Processed", ["status"]
)

AWS_ENDPOINT= os.getenv("AWS_ENDPOINT_URL","http://localhost:4566")
AWS_DEFAULT_REGION = os.getenv("AWS_DEFAULT_REGION","us-east-1")
SQS_QUEUE_URL = os.getenv(
    "SQS_QUEUE_URL", "http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/orders-queue"
)
DYNAMODB_TABLE = os.getenv("DYNAMODB_TABLE", "orders-table")

sqs = boto3.client("sqs",endpoint_url=AWS_ENDPOINT,region_name=AWS_DEFAULT_REGION);
dynamodb = boto3.resource("dynamodb",AWS_ENDPOINT=AWS_ENDPOINT, region_name = AWS_DEFAULT_REGION)

class OrderPayLoad(BaseModel):
    item:str = "cloud-sandbox"
    quantity: int  = 1


@app.get("/health")
def health_check():
    return {"status":"healthy"}


@app.post("/order")
def create_order(payload: OrderPayLoad):
    order_id = str(uuid.uuid4())
    timestamp = datetime.now(timezone.utc).isoformat()

    try:
        # 1. Push event to the SQS Queue
        sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody= json.dumps(
                {"order_id":order_id, "item":payload.item, "quantity":payload.quantity}
            ),
        )

        # 2. Update the dynamodb table
        table = dynamodb.TABLE(DYNAMODB_TABLE)
        table.put_item(
            Item={
                "order_id": order_id,
                "item":payload.item,
                "quantity": payload.quantity,
                "timestamp": timestamp,
                "status" : "QUEUED"
            }
        )

        ORDER_PROCESSED.labels(status="success").inc()
        return {"order_id":order_id, "status" : "QUEUED" }
    except(BotoCoreError,ClientError) as e:
        ORDER_PROCESSED.labels(status="error").inc()
        raise HTTPException(status_code=500, detail=str(e))
