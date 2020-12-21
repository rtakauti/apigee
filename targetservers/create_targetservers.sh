#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh

targets="$ROOT_DIR/recover/targets"
while IFS= read -r target; do
  CURL_RESULT=$(curl --location --request POST --insecure "$APIGEE"/v1/organizations/"$ORG"/environments/"$ENV"/targetservers \
    --user "$USERNAME:$PASSWORD" \
    --silent \
    --write-out "%{http_code}" \
    --output /dev/null \
    --header 'Content-Type: application/json' \
    --data-raw "$target")
  status "$CURL_RESULT" "$target"
done <"$targets"
