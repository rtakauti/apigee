#!/usr/bin/env bash

function setContext() {
  CONTEXT=$(basename "$(pwd)")
}

function setActivity() {
  ACTIVITY="$(echo "${0##*/}" | cut -d'_' -f1)"
}

function makeDir() {
  local backup_dir
  export LOG

  setContext
  setActivity

  LOG="$ACTIVITY/$DATE/$ORG/$CONTEXT"
  backup_dir="$ACTIVITY/$DATE/$ORG"

  if [[ "$CONTEXT" == 'apigee' ]] ||
    [[ "$CONTEXT" == 'organizations' ]] ||
    [[ "$CONTEXT" == 'users' ]]; then
    backup_dir="$ACTIVITY/$DATE"
    LOG="$ACTIVITY/$DATE/$CONTEXT"
  fi

  LOG+=".log"
  mkdir -p "$backup_dir"
}

function header() {
  local columns

  columns=$(tput cols)
  echo ----------------------------------------------------------------------------------------------------------------------------------- | tee -a "$LOG"
  printf "%*s\n" $(((${#CONTEXT} + columns) / 2)) "START ${ACTIVITY^^} ${ORG^^} ${ENV^^} ${CONTEXT^^} - $DATE" | tee -a "$LOG"
  echo ----------------------------------------------------------------------------------------------------------------------------------- | tee -a "$LOG"
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
  cat "$LOG" >>"$ROOT_DIR/$ACTIVITY/$DATE/apigee_log.txt"
  (
    cd "$ROOT_DIR/$CONTEXT/$ACTIVITY/$DATE" || return
    mkdir -p "$ROOT_DIR/$ACTIVITY/$DATE/$CONTEXT"
    cp -r ./* "$ROOT_DIR/$ACTIVITY/$DATE/$CONTEXT"
  )
}

function compress() {
  (
    cd "$ACTIVITY" || return
    7z a -r "${CONTEXT^^}_$DATE".zip "./$DATE/*" >/dev/null
    echo "$DATE" >>'list.txt'
    rm -rf "$DATE"
  )
}
