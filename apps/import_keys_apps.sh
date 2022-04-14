#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh

apps="$ROOT_DIR/recover/apps_keys"

while IFS= read -r keys; do
  IFS=':' read -ra app <<<"$keys"
    CONSUMER_KEY=$(curl --location --request POST --insecure "$URL"/v1/organizations/"$ORG"/companies/"$COMPANY"/apps \
        --user "$USERNAME:$PASSWORD" \
        --silent \
        --header 'Content-Type: application/json' \
        --data-raw '{"apiProducts":["'"${app[0]}"'"],"name": "'"${app[0]}"'"}' | 
        jq  '. |  .credentials | .[].consumerKey ' |
        sed 's/\"//g')

    app_uri=$(echo ${app[0]} | sed -e 's/ /%20/g')

    CURL_RESULT=$(curl --location --request DELETE --insecure "$URL"/v1/organizations/"$ORG"/companies/"$COMPANY"/apps/"$app_uri"/keys/"$CONSUMER_KEY" \
        --user "$USERNAME:$PASSWORD" \
        --silent \
        --write-out "%{http_code}" \
        --output /dev/null \
        --header 'Content-Type: application/json')
        status "$CURL_RESULT" deleted "$CONSUMER_KEY" into "$app"

    SUBSCRIPTION_KEY="${app[1]}"

    CURL_RESULT=$(curl --location --request POST --insecure "$URL"/v1/organizations/"$ORG"/companies/"$COMPANY"/apps/"$app_uri"/keys/create \
        --user "$USERNAME:$PASSWORD" \
        --silent \
        --write-out "%{http_code}" \
        --output /dev/null \
        --header 'Content-Type: application/json' \
        --data-raw '{"consumerKey":"'"$SUBSCRIPTION_KEY"'","consumerSecret":"'"$COMPANY"'"}')
        status "$CURL_RESULT" created "$SUBSCRIPTION_KEY" into "$app"
  
done <"$apps"
