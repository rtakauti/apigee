#!/usr/bin/env bash

function makeDir() {
  BACKUP_DIR="$ROOT_DIR/backup/$DATE"
  RECOVER_DIR="$ROOT_DIR/recover/$DATE"
  RECOVER="$ROOT_DIR/recover"
  UPDATE_DIR="$ROOT_DIR/update/$DATE"
  DELETE_DIR="$ROOT_DIR/delete/$DATE"
  REMOVE="$ROOT_DIR/remove"
  CREATE_DIR="$ROOT_DIR/create/$DATE"
  ACTIVITY="$(echo "${0##*/}" | cut -d'_' -f1)"
  CONTEXT=$(basename "$(pwd)")
  ACTIVITY_DIR="$ACTIVITY/$DATE/$ORG"
  SUFFIX="${CONTEXT}_$ORG"

  if [[ -n $ENV ]]; then
    ACTIVITY_DIR="$ACTIVITY_DIR/$ENV"
    SUFFIX="${SUFFIX}_$ENV"
  fi

  mkdir -p "$ACTIVITY_DIR"
  FILENAME="$ACTIVITY_DIR/$CONTEXT"
  LOG="${FILENAME}_log.txt"

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

function header() {
  local columns

  columns=$(tput cols)
  echo --------------------------------------------------------------------------------------------------------- | tee -a "$LOG"
  printf "%*s\n" $(((${#CONTEXT} + columns) / 3)) "START ${ACTIVITY^^} ${ENV^^} ${CONTEXT^^} - $DATE" | tee -a "$LOG"
  echo --------------------------------------------------------------------------------------------------------- | tee -a "$LOG"
}

function status() {
  if [ "${CURL_RESULT}" -eq 200 ] || [ "${CURL_RESULT}" -eq 204 ] || [ "${CURL_RESULT}" -eq 201 ]; then
    echo success "$*" | tee -a "$LOG"
  elif [ "${CURL_RESULT}" -eq 400 ]; then
    echo bad request "$*" | tee -a "$LOG"
  elif [ "${CURL_RESULT}" -eq 401 ]; then
    echo unauthorized "$*" | tee -a "$LOG"
  elif [ "${CURL_RESULT}" -eq 403 ]; then
    echo forbidden "$*" | tee -a "$LOG"
  elif [ "${CURL_RESULT}" -eq 404 ]; then
    echo not found "$*" | tee -a "$LOG"
  elif [ "${CURL_RESULT}" -eq 409 ]; then
    echo conflict "$*" | tee -a "$LOG"
  else
    echo error "$*" | tee -a "$LOG"
  fi
}

function copy() {
  local parent
  local parent_log

  parent=$(dirname "$PWD")
  parent_log="$ROOT_DIR/$ACTIVITY/$DATE/$ORG"/$(basename "$parent")_log.txt

  if [[ -f "$parent_log" ]]; then
    cat "$LOG" >>"$parent_log"
  fi
}

function compress() {
  CONTEXT=$(basename "$(pwd)")

  (
    cd "$ACTIVITY" || exit
    if [[ "$CONTEXT" == 'apigee' ]]; then
      7z a -r "${CONTEXT^^}_$DATE".zip "$DATE" >/dev/null
    else
      mkdir -p "$ROOT_DIR/$ACTIVITY/$DATE/$ORG"
      7z a -r "${CONTEXT^^}_$DATE".zip "./$DATE/$ORG/*.*" >/dev/null
      mv "${CONTEXT^^}_$DATE.zip" "$ROOT_DIR/$ACTIVITY/$DATE/$ORG/${CONTEXT^^}_$DATE.zip"
      7z a -r "${CONTEXT^^}_$DATE".zip "$DATE" >/dev/null
    fi
    rm -rf "$DATE"
  )

  if [[ "$MASS" != true ]]; then
    (
      cd "$ROOT_DIR/$ACTIVITY" || exit
      7z a -r "APIGEE_$DATE".zip "$DATE" >/dev/null
      rm -rf "$DATE"
    )
  fi

  if [[ "$ACTIVITY" == 'backup' ]]; then
    (
      cd "$RECOVER" || exit
      7z a -r "RECOVER_$DATE".zip "./$DATE/*.txt" >/dev/null
      rm -rf "$DATE"
    )
  fi
}

function makeCurl() {
  local specify

  specify="$1"
  CURL_RESULT=$(
    curl --location --request "$VERB" \
      --insecure "$APIGEE/v1/$URI${specify}" \
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

  VERB='GET'
  URI="$1"
  type="$2"
  jq_query="$3"
  file="${FILENAME}_${type}.json"

  if [[ -z "$type" ]]; then
    file="$FILENAME.json"
  fi

  makeCurl
  status "$CURL_RESULT backup done see $file"
  payload=$(jq <"$TEMP")
  echo "$payload" >"$file"

  if [[ -z "$payload" ]]; then
    echo 'no items found' | tee -a "$LOG"
    return
  fi

  if [[ "$type" == 'list' ]]; then
    LIST=$(echo "$payload" | jq '.[]' | sed 's/\"//g')
    echo "$payload" | jq 'map(.+"|not_delete") | .[]' | sed 's/\"//g' >"$REMOVE/$SUFFIX.txt"

    if [[ "$CONTEXT" == 'environments' ]]; then
      printf "export ENVS=(%s)\n" "$(echo "$payload" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g')" >"$ROOT_DIR/environments.sh"
    fi

    if [[ "$CONTEXT" == 'organizations' ]]; then
      printf "export ORGS=(%s)\n" "$(echo "$payload" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g')" >"$ROOT_DIR/organizations.sh"
    fi

  fi

  if [[ "$type" == 'jq' ]]; then
    LIST=$(echo "$payload" | jq "$jq_query" | sed 's/\"//g')
  fi
}

function makeBackupSub() {
  local sub_file
  local sub_uri
  local object
  local object_uri
  local payload
  local revision_dir
  local name

  if [[ -z "$LIST" ]]; then
    return
  fi

  ACTION="$1"
  name='name'

  if [[ -n "$2" ]]; then
    sub_uri="/$2"
  fi

  if [[ "$CONTEXT" == 'developers' ]] || [[ "$CONTEXT" == 'users' ]]; then
    name='email'
  fi

  for object in $LIST; do
    sub_file="$ACTIVITY_DIR/$object.json"

    if [[ "$type" == 'jq' ]]; then
      IFS='|' read -ra object <<<"$object"
      sub_file="$ACTIVITY_DIR/${object[1]}.json"
    fi

    object_uri="${object// /%20}"
    makeCurlObject "$sub_uri"
    status "$CURL_RESULT backup done see $sub_file"
    payload=$(jq <"$TEMP")
    echo "$payload" >"$sub_file"

    if [[ "$ACTION" == 'revision' ]]; then
      for revision in $(echo "$payload" | jq '.revision | .[]' | sed 's/\"//g'); do
        revision_dir="$ROOT_DIR/revisions/$CONTEXT/$object/$revision"
        mkdir -p "$revision_dir"
        (
          cd "$revision_dir" || exit
          makeCurlObject "/revisions/${revision}?format=bundle"
          7z x "$TEMP" >/dev/null
        )
        status "$CURL_RESULT revision done see revision/$object/revision_${revision}.zip"
      done
    fi

    payload=$(echo "$payload" | jq -c '. |  del(.createdAt,.createdBy,.lastModifiedAt,.lastModifiedBy,.organization,.apps,.metaData,.revision)')
    echo "$payload" >>"$FILENAME.txt"

    if [[ "$ACTION" == 'status' ]]; then
      paste -d "|" <(echo "$payload" | jq --arg name "$name" '.[$name]' | sed 's/\"//g') <(echo "$payload" | jq '.status' | sed 's/\"//g') >>"${FILENAME}_status.txt"
    fi

    paste -d "|" <(echo "$payload" | jq --arg name "$name" '.[$name]' | sed 's/\"//g') <(echo "$payload" | jq -c 'del(.name,.status)') >>"${FILENAME}_change.txt"

  done

  cp "$FILENAME.txt" "$RECOVER/$SUFFIX.txt"
  cp "$FILENAME.txt" "$RECOVER_DIR/$SUFFIX.txt"

  if [[ "$ACTION" == 'status' ]]; then
    mv "${FILENAME}_status.txt" "$ROOT_DIR/change/${SUFFIX}_status.txt"
  fi

  if [[ "$CONTEXT" != 'apis' ]] && [[ "$CONTEXT" != 'sharedflows' ]]; then
    mv "${FILENAME}_change.txt" "$ROOT_DIR/change/${SUFFIX}_change.txt"
  else
    rm "${FILENAME}_change.txt"
  fi
}

function create() {
  local object
  local object_file
  local sub_file

  VERB='POST'
  object_file="$RECOVER/$SUFFIX.txt"
  URI="$1"

  if [[ ! -f "$object_file" ]]; then
    echo 'recover file not found' | tee -a "$LOG"
    return
  fi

  cp "$object_file" "$ACTIVITY_DIR/$CONTEXT.txt"
  while IFS= read -r object; do
    CONTENT_TYPE='Content-Type: application/json'
    DATA="$object"
    makeCurl
    status "$CURL_RESULT recover done from $object"
    sub_file=$(echo "$object" | jq '.name' | sed 's/\"//g')
    cat <"$TEMP" | jq >"$ACTIVITY_DIR/$sub_file.json"
  done <"$object_file"
}

function update() {
  local object
  local objects
  local object_uri
  local change_file
  local status_file
  local sub_uri

  VERB='PUT'
  change_file="$ROOT_DIR/change/${SUFFIX}_change.txt"
  status_file="$ROOT_DIR/change/${SUFFIX}_status.txt"
  URI="$1"

  if [[ "$UPDATE" != 'ON' ]]; then
    echo 'permission to update is disable' | tee -a "$LOG"
    return
  fi

  if [[ ! -f "$change_file" ]] && [[ ! -f "$status_file" ]]; then
    echo 'update file not found' | tee -a "$LOG"
    return
  fi

  if [[ -n "$2" ]]; then
    sub_uri="/$2"
  fi

  cp "$change_file" "$ACTIVITY_DIR/${CONTEXT}_change.txt"

  if [[ -f "$status_file" ]]; then
    cp "$status_file" "$ACTIVITY_DIR//${CONTEXT}_status.txt"
    while IFS= read -r objects; do
      IFS='|' read -ra object <<<"$objects"
      object_uri="${object[0]}?action=${object[1]}"
      CONTENT_TYPE='Content-Type: application/octet-stream'
      makeCurlObject
      status "$CURL_RESULT updated ${object[0]} to status ${object[1]}"
    done <"$status_file"
  fi

  while IFS= read -r objects; do
    IFS='|' read -ra object <<<"$objects"
    object_uri="${object[0]}"
    CONTENT_TYPE='Content-Type: application/json'
    DATA="${object[1]}"
    makeCurlObject "$sub_uri"
    status "$CURL_RESULT updated ${object[0]} to ${object[1]}"
    cat <"$TEMP" | jq >"$ACTIVITY_DIR/${object[0]}.json"
  done <"$change_file"
}

function delete() {
  local object
  local objects
  local object_file
  local flag
  local sub_uri

  VERB='DELETE'
  object_file="$REMOVE/$SUFFIX.txt"
  URI="$1"

  if [[ "$DELETE" != 'ON' ]]; then
    echo 'permission to delete is disable' | tee -a "$LOG"
    return
  fi

  if [[ ! -f "$object_file" ]]; then
    echo 'remove file not found' | tee -a "$LOG"
    return
  fi
  cp "$object_file" "$ACTIVITY_DIR/$CONTEXT.txt"

  while IFS= read -r objects; do
    IFS='|' read -ra object <<<"$objects"

    if [[ "${object[1]}" == 'delete' ]]; then
      flag=1
      object_uri="${object[0]}"
      makeCurlObject
      status "$CURL_RESULT remove ${object[0]}"
      cat <"$TEMP" | jq >"$ACTIVITY_DIR/${object[0]}.json"
    fi
  done <"$object_file"

  if [[ -z "$flag" ]]; then
    echo 'nothing was deleted' | tee -a "$LOG"
  fi
}

function mass() {
  activity 'organizations'
  activity 'environments'
  activity 'users'
  activity 'companies'
  #  activity 'targetservers'
  #  activity 'apiproducts'
  #  activity 'developers'
  #  activity 'apis'
  #  activity 'sharedflows'
  #  activity 'virtualhosts'
  #  activity 'keyvaluemaps'
  #  activity 'userroles'
  #  activity 'caches'
  #  activity 'keystores'
  #  activity 'references'
  #  activity 'reports'
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
    if [[ -f "${ACTIVITY}_${context}".sh ]]; then
      bash "${ACTIVITY}_${context}".sh
    fi
  )
}

function clean() {
  local context
  local activity
  declare -a activities=("backup" "create" "update" "delete")

  context="$1"
  for activity in "${activities[@]}"; do
    if [[ -d "$context/$activity" ]]; then
      (
        cd "$context/$activity" || exit
        rm -rf ./*
      )
    fi
  done
}

function linux() {
  local context

  context="$1"
  (
    cd "$context" || exit
    dos2unix ./*.*
  )
}
