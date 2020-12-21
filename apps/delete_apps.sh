#!/usr/bin/env bash

source ../functions.sh
source ../env_var.sh

apps="$ROOT_DIR/recover/apps_keys"

while IFS= read -r keys; do
  IFS=':' read -ra app <<<"$keys"

  app_uri=$(echo ${app[0]} | sed -e 's/ /%20/g')
  
  CURL_RESULT=$(curl --location --request DELETE --insecure "$APIGEE"/v1/organizations/"$ORG"/companies/"$COMPANY"/apps/"$app_uri" \
  --user "$USERNAME:$PASSWORD" \
  --silent \
  --write-out "%{http_code}" \
  --output /dev/null)
  status "$CURL_RESULT" deleting "$app"
done <"$apps"