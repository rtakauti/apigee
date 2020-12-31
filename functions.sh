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
  ACTIVITY_DIR="$ACTIVITY/$DATE"
  SUFFIX="$CONTEXT"

  if [[ -n $ENV ]]; then
    RECOVER_DIR="$ROOT_DIR/recover/$DATE/$ENV"
    ACTIVITY_DIR="$ACTIVITY/$DATE/$ENV"
    SUFFIX="${CONTEXT}_$ENV"
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
  parent_log="$ROOT_DIR/$ACTIVITY/$DATE"/$(basename "$parent")_log.txt

  if [[ -f "$parent_log" ]]; then
    cat "$FILENAME"_log.txt >>"$parent_log"
  fi
}

function compress() {
  local context_dir
  local recover_dir

  context_dir="$ROOT_DIR/$ACTIVITY/$DATE"
  recover_dir="$ROOT_DIR/recover"
  CONTEXT=$(basename "$(pwd)")

  (
    cd "$ACTIVITY" || exit
    7z a -r "${CONTEXT^^}_$DATE".zip "$DATE" >/dev/null
    cp "${CONTEXT^^}"_"$DATE".zip "$context_dir"
    rm -rf "$DATE"
  )

  if [[ "$ACTIVITY" == 'backup' ]]; then
    (
      cd "$recover_dir" || exit
      7z a -r "RECOVER_$DATE".zip "$recover_dir/$DATE" >/dev/null
      rm -rf "${recover_dir:?}/$DATE"
    )
  fi

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
    echo "$LIST" | sed 's/$/|not_delete/' >"$REMOVE/$SUFFIX.txt"
    if [[ "$CONTEXT" == 'environments' ]]; then
      printf "export ENVS=(%s)\n" "$(echo "$payload" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g')" >"$ROOT_DIR/environments.sh"
    fi
  fi

  if [[ "$type" == 'jq' ]]; then
    LIST=$(echo "$payload" | jq "$jq_query" | sed 's/\"//g')
  fi
}

function makeBackupSub() {
  local sub_file
  local object
  local object_uri
  local payload
  local revision_dir
  local name

  ACTION=$1
  name='name'

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
    makeCurlObject
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

  cat "$FILENAME.txt" >"$RECOVER_DIR/$CONTEXT.txt"
  cp "$FILENAME.txt" "$RECOVER/$SUFFIX.txt"

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

  URI="$1"
  VERB='POST'
  object_file="$RECOVER/$SUFFIX.txt"

  if [[ ! -f "$object_file" ]]; then
    echo 'recover file not found' | tee -a "$LOG"
    return
  fi

  cp "$object_file" "$ACTIVITY_DIR/$SUFFIX.txt"
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
  local change_file
  local status_file
  local sub_uri

  sub_uri="$1"
  ACTION="$2"
  VERB='PUT'
  change_file="$ROOT_DIR/change/${SUFFIX}_change.txt"
  status_file="$ROOT_DIR/change/${SUFFIX}_status.txt"

  if [[ "$UPDATE" != 'ON' ]]; then
    echo 'permission to update is disable' | tee -a "$LOG"
    return
  fi

  if [[ ! -f "$change_file" ]] && [[ ! -f "$status_file" ]]; then
    echo 'update file not found' | tee -a "$LOG"
    return
  fi

  cp "$change_file" "$ACTIVITY_DIR"

  if [[ -f "$status_file" ]]; then
    cp "$status_file" "$ACTIVITY_DIR"
    while IFS= read -r objects; do
      IFS='|' read -ra object <<<"$objects"
      URI="$sub_uri/${object[0]}?action=${object[1]}"
      CONTENT_TYPE='Content-Type: application/octet-stream'
      makeCurl
      status "$CURL_RESULT updated ${object[0]} to status ${object[1]}"
    done <"$status_file"
  fi

  while IFS= read -r objects; do
    IFS='|' read -ra object <<<"$objects"
    URI="$sub_uri/${object[0]}"
    CONTENT_TYPE='Content-Type: application/json'
    DATA="${object[1]}"
    makeCurl
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
  sub_uri="$1"

  if [[ "$DELETE" != 'ON' ]]; then
    echo 'permission to delete is disable' | tee -a "$LOG"
    return
  fi

  if [[ ! -f "$object_file" ]]; then
    echo 'remove file not found' | tee -a "$LOG"
    return
  fi
  cp "$object_file" "$ACTIVITY_DIR/$SUFFIX.txt"

  while IFS= read -r objects; do
    IFS='|' read -ra object <<<"$objects"

    if [[ "${object[1]}" == 'delete' ]]; then
      flag=1
      URI="$sub_uri/${object[0]}"
      makeCurl
      status "$CURL_RESULT remove ${object[0]}"
      cat <"$TEMP" | jq >"$ACTIVITY_DIR/${object[0]}.json"
    fi
  done <"$object_file"

  if [[ -z "$flag" ]]; then
    echo 'nothing was deleted' | tee -a "$LOG"
  fi
}

function mass() {
  activity 'environments'
  activity 'companies'
  activity 'targetservers'
  #  activity 'apiproducts'
  #    activity 'developers'
  #  activity 'apis'
  #  activity 'sharedflows'
  #  activity 'users'
  #        activity 'virtualhosts'
  #      activity 'keyvaluemaps'
  #      activity 'userroles'
  #      activity 'caches'
  #      activity 'keystores'
  #      activity 'references'
  #      activity 'reports'
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
