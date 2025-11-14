#!/bin/bash

# loadgen.sh
TARGET="http://<NGINX_SERVICE_CLUSTER_IP_OR_NODEPORT>/"
CONCURRENCY=10

bombard() {
  while true; do
    curl -s $TARGET > /dev/null
  done
}

for i in $(seq 1 $CONCURRENCY); do
  bombard &
done

echo "Load generator started with $CONCURRENCY parallel requests to $TARGET"
echo "Press Ctrl+C to stop."
wait
