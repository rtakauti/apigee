#!/usr/bin/env bash

function makeCurl() {
  export CURL_RESULT

  CURL_RESULT=$(
    curl --location --request "$VERB" \
      --insecure "$APIGEE/v1/$uri" \
      --output "$TEMP" \
      --user "$USERNAME:$PASSWORD" \
      --silent \
      --header "$CONTENT_TYPE" \
      --write-out "%{http_code}" \
      --data "$DATA"
  )
}
