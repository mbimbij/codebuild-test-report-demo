#! /bin/bash
PORT=8080
RETRY_INTERVAL_SECONDS=2
until curl -X GET "http://localhost:$PORT"
do
  echo "Application not listening yet on port $PORT. Retrying in $RETRY_INTERVAL_SECONDS second(s)..."
  sleep $RETRY_INTERVAL_SECONDS
done