#!/usr/bin/env bash

function makeCurl() {
  declare -a arguments
  export CURL_RESULT

  arguments=("$@")
  CURL_RESULT=$(
    curl "${arguments[@]}" --request "$VERB" \
      "$URL/v1/$URI" \
      --output "$TEMP" \
      --user "$USERNAME:$PASSWORD" \
      --header "$CONTENT_TYPE" \
      --write-out "%{http_code}" \
      --insecure \
      --silent \
      --location
  )
}
