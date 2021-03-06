#!/usr/bin/env bash

function status() {
  local log

  log="$ACTIVITY/$DATE/$CONTEXT"_log.txt

  if [ "${CURL_RESULT}" -eq 200 ] || [ "${CURL_RESULT}" -eq 204 ] || [ "${CURL_RESULT}" -eq 201 ]; then
    echo success "$*" | tee -a "$log"
  elif [ "${CURL_RESULT}" -eq 404 ]; then
    echo not found "$*" | tee -a "$log"
  elif [ "${CURL_RESULT}" -eq 409 ]; then
    echo conflict "$*" | tee -a "$log"
  else
    echo error "$*" | tee -a "$log"
  fi
}

function makeDir() {
  BACKUP_DIR="$ROOT_DIR/backup/$DATE"
  RECOVER_DIR="$ROOT_DIR/recover/$DATE"
  UPDATE_DIR="$ROOT_DIR/update/$DATE"
  DELETE_DIR="$ROOT_DIR/delete/$DATE"
  CREATE_DIR="$ROOT_DIR/delete/$DATE"
  ACTIVITY="$(echo "${0##*/}" | cut -d'_' -f1)"
  CONTEXT=$(basename "$(pwd)")
  mkdir -p "$ACTIVITY/$DATE"

  if [[ "$ACTIVITY" == 'backup' ]]; then
    mkdir -p "$RECOVER_DIR"
    mkdir -p "$BACKUP_DIR"
  elif [[ "$ACTIVITY" == 'update' ]]; then
    mkdir -p "$UPDATE_DIR"
  elif [[ "$ACTIVITY" == 'delete' ]]; then
    mkdir -p "$DELETE_DIR"
  elif [[ "$ACTIVITY" == 'create' ]]; then
    mkdir -p "$CREATE_DIR"
  fi

  header
}

function copy() {
  local parent
  local parent_log

  parent=$(dirname "$PWD")
  parent_log="$ROOT_DIR/$ACTIVITY/$DATE"/$(basename "$parent")_log.txt

  if [[ "$ACTIVITY" == 'backup' ]]; then
    cat "$FILENAME.txt" >"$RECOVER_DIR/$CONTEXT.txt"
    cp "$FILENAME.txt" "$ROOT_DIR/recover/$CONTEXT.txt"
  fi

  if [[ "$ACTION" == 'update' ]]; then
    cp "${FILENAME}_status.txt" "$ROOT_DIR/change/${CONTEXT}.txt"
  fi

  if [[ -f "$parent_log" ]]; then
    cat "$FILENAME"_log.txt >>"$parent_log"
  fi
}

function compress() {
  local activity_dir
  local recover_dir

  activity_dir="$ROOT_DIR/$ACTIVITY/$DATE"
  recover_dir="$ROOT_DIR/recover"
  CONTEXT=$(basename "$(pwd)")

  (
    cd "$ACTIVITY" || exit
    7z a -r "${CONTEXT^^}_$DATE".zip "$DATE" >/dev/null
    cp "${CONTEXT^^}"_"$DATE".zip "$activity_dir"
    rm -fr "$DATE"
  )

  if [[ "$ACTIVITY" == 'backup' ]]; then
    (
      cd "$recover_dir" || exit
      7z a -r "RECOVER_$DATE".zip "$recover_dir/$DATE" >/dev/null
      rm -rf "${recover_dir:?}/$DATE"
    )
  fi
}

function header() {
  local log
  local columns

  log="$ACTIVITY/$DATE/${CONTEXT}_log.txt"
  columns=$(tput cols)
  echo --------------------------------------------------------------------------------------------------------- | tee -a "$log"
  printf "%*s\n" $(((${#CONTEXT} + columns) / 3)) "START ${ACTIVITY^^} ${CONTEXT^^} - $DATE" | tee -a "$log"
  echo --------------------------------------------------------------------------------------------------------- | tee -a "$log"

}

function makeCurl() {
  local specify

  specify="$1"
  CURL_RESULT=$(
    curl --location --request "$VERB" \
      --insecure "$APIGEE/v1/organizations/$ORG/$URI${specify}" \
      --output "$TEMP" \
      --user "$USERNAME:$PASSWORD" \
      --silent \
      --header "$CONTENT_TYPE" \
      --write-out "%{http_code}" \
      --data "$DATA"
  )
}

function makeCurlObject() {
  local specify

  specify="$1"
  makeCurl "/${object_uri}${specify}"
}

function makeBackupList() {
  local file
  local jq_query

  URI="$1"
  type="$2"
  jq_query="$3"
  VERB='GET'
  FILENAME="$ACTIVITY/$DATE/$CONTEXT"
  file="${FILENAME}_${type}.json"

  if [[ -z "$type" ]]; then
    file="$FILENAME.json"
  fi

  makeCurl
  status "$CURL_RESULT backup done see $file"
  payload=$(jq <"$TEMP")
  echo "$payload" >"$file"

  if [[ "$type" == 'list' ]]; then
    LIST=$(echo "$payload" | jq '.[]' | sed 's/\"//g')
    echo "$LIST" | sed 's/$/|not_delete/' >"$ROOT_DIR/remove/$CONTEXT.txt"
  fi

  if [[ "$type" == 'jq' ]]; then
    LIST=$(echo "$payload" | jq "$jq_query" | sed 's/\"//g')
  fi
}

function makeBackupSub() {
  local sub_file
  local object_uri
  local payload
  local revision_dir

  ACTION=$1

  for object in $LIST; do
    sub_file="$ACTIVITY/$DATE/$object.json"

    if [[ "$type" == 'jq' ]]; then
      IFS='|' read -ra object <<<"$object"
      sub_file="$ACTIVITY/$DATE/${object[1]}.json"
    fi

    object_uri="${object// /%20}"
    makeCurlObject
    status "$CURL_RESULT backup done see $sub_file"
    payload=$(jq <"$TEMP")
    echo "$payload" >"$sub_file"

    if [[ "$ACTION" == 'revision' ]]; then
      for revision in $(echo "$payload" | jq '.revision | .[]' | sed 's/\"//g'); do
        revision_dir="$ROOT_DIR/revision/$CONTEXT/$object"
        mkdir -p "$revision_dir"
        (
          cd "$revision_dir" || exit
          makeCurlObject "/revisions/${revision}?format=bundle"
          cp "$TEMP" "revision_${revision}.zip"
        )
        status "$CURL_RESULT revision done see revision/$object/revision_${revision}.zip"
      done
    fi

    payload=$(echo "$payload" | jq -c '. |  del(.createdAt,.createdBy,.lastModifiedAt,.lastModifiedBy,.organization,.apps,.metaData,.revision)')
    echo "$payload" >>"$FILENAME.txt"

    if [[ "$ACTION" == 'update' ]]; then
      paste -d "|" <(echo "$payload" | jq '. | (.name+"|"+.status)' | sed 's/\"//g') <(echo "$payload" | jq -c '. |  del(.name,.status)') >>"${FILENAME}_status.txt"
    fi

  done
}

function create() {
  local object
  local object_file
  local sub_file
  local log

  URI="$1"
  FILENAME="$ACTIVITY/$DATE/$CONTEXT"
  VERB='POST'
  log="$ACTIVITY/$DATE/$CONTEXT"_log.txt
  object_file="$ROOT_DIR/recover/$CONTEXT.txt"

  if [[ ! -f "$object_file" ]]; then
    echo 'recover file not found' | tee -a "$log"
    return
  fi

  cp "$object_file" "$ACTIVITY/$DATE/recover.txt"
  while IFS= read -r object; do
    CONTENT_TYPE='Content-Type: application/json'
    DATA="$object"
    makeCurl
    status "$CURL_RESULT recover done from $object"
    sub_file=$(echo "$object" | jq '.name' | sed 's/\"//g')
    cat <"$TEMP" | jq >"$ACTIVITY/$DATE/$sub_file.json"
  done <"$object_file"
}

function update() {
  local object
  local objects
  local object_file
  local log

  FILENAME="$ACTIVITY/$DATE/$CONTEXT"
  VERB='PUT'
  object_file="$ROOT_DIR/change/${CONTEXT}.txt"
  log="$ACTIVITY/$DATE/$CONTEXT"_log.txt

  if [[ ! -f "$object_file" ]]; then
    echo 'update file not found' | tee -a "$log"
    return
  fi
  cp "$object_file" "$ACTIVITY/$DATE/change.txt"

  while IFS= read -r objects; do
    IFS='|' read -ra object <<<"$objects"

    URI="$CONTEXT/${object[0]}?action=${object[1]}"
    CONTENT_TYPE='Content-Type: application/octet-stream'
    makeCurl
    status "$CURL_RESULT updated ${object[0]} to ${object[1]}"

    URI="$CONTEXT/${object[0]}"
    CONTENT_TYPE='Content-Type: application/json'
    DATA="${object[2]}"
    makeCurl
    status "$CURL_RESULT updated ${object[0]} to ${object[2]}"

    cat <"$TEMP" | jq >"$ACTIVITY/$DATE/${object[0]}.json"
  done <"$object_file"
}

function delete() {
  local object
  local objects
  local object_file
  local log
  local flag

  FILENAME="$ACTIVITY/$DATE/$CONTEXT"
  VERB='DELETE'
  object_file="$ROOT_DIR/remove/$CONTEXT.txt"
  log="$ACTIVITY/$DATE/${CONTEXT}_log.txt"

  if [[ "$DELETE" != 'ON' ]]; then
    echo 'permission to delete is disable' | tee -a "$log"
    return
  fi

  if [[ ! -f "$object_file" ]]; then
    echo 'remove file not found' | tee -a "$log"
    return
  fi
  cp "$object_file" "$ACTIVITY/$DATE/remove.txt"

  while IFS= read -r objects; do
    IFS='|' read -ra object <<<"$objects"

    if [[ "${object[1]}" == 'delete' ]]; then
      flag=1
      URI="$CONTEXT/${object[0]}"
      makeCurl
      status "$CURL_RESULT remove ${object[0]}"
      cat <"$TEMP" | jq >"$ACTIVITY/$DATE/${object[0]}.json"
    fi
  done <"$object_file"

  if [[ -z "$flag" ]]; then
    echo 'nothing was deleted' | tee -a "$log"
  fi
}

function mass() {
  activity 'companies'
  activity 'apiproducts'
  #    activity 'keyvaluemaps'
  #    activity 'targetservers'
  #    activity 'apis'
  #    activity 'userroles'
  #    activity 'sharedflows'
  #    activity 'caches'
  #    activity 'users'
  #    activity 'developers'
  #    activity 'virtualhosts'
  #    activity 'keystores'
  #    activity 'references'
  #    activity 'reports'
  #    activity 'environments'
}

function activity() {
  local context

  context="$1"
  if [[ "$ACTIVITY" == 'clean' ]]; then
    clean "$context"
  elif [[ "$ACTIVITY" == 'linux' ]]; then
    linux "$context"
  else
    execute "$context"
  fi
}

function execute() {
  local context

  context="$1"
  (
    cd "$context" || exit
    bash "${ACTIVITY}_${context}".sh
  )
}

function clean() {
  local context
  context="$1"

  (
    cd "$context/backup" || exit
    rm -rf ./*
  )
  (
    cd "$context/create" || exit
    rm -rf ./*
  )
  (
    cd "$context/update" || exit
    rm -rf ./*
  )
  (
    cd "$context/delete" || exit
    rm -rf ./*
  )
}

function linux() {
  local context

  context="$1"
  (
    cd "$context" || exit
    dos2unix ./*.*
  )
}
