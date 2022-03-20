#!/usr/bin/env bash

function setContext() {
  CONTEXT=$(basename "$(pwd)")
}

function setActivity() {
  ACTIVITY="$(echo "${0##*/}" | cut -d'_' -f1)"
}

function setLog() {
  log="$ROOT_DIR/$CONTEXT/$ACTIVITY/$DATE/$CONTEXT"
  [[ "$CONTEXT" == 'apigee' ]] && log="$ROOT_DIR/$ACTIVITY/$DATE/$CONTEXT"
  log+=".log"
}

function makeDir() {
  setContext
  setActivity
  mkdir -p "$ACTIVITY/$DATE"
  mkdir -p "$ROOT_DIR/$ACTIVITY/$DATE"
}

function header() {
  local columns
  local log
  local title

  setLog
  columns=$(tput cols)
  title="START ${ACTIVITY^^}"
  [[ "$ORG" ]] && title+=" ${ORG^^}"
  [[ "$ENV" ]] && title+=" ${ENV^^}"
  title+=" ${CONTEXT^^} - $DATE"

  echo ----------------------------------------------------------------------------------------------------------------------------------- | tee -a "$log"
  printf "%*s\n" $(((${#CONTEXT} + columns) / 2)) "$title" | tee -a "$log"
  echo ----------------------------------------------------------------------------------------------------------------------------------- | tee -a "$log"
}

function status() {
  local log

  setLog
  if [ "${CURL_RESULT}" -eq 200 ] || [ "${CURL_RESULT}" -eq 204 ] || [ "${CURL_RESULT}" -eq 201 ]; then
    echo success "$*" | tee -a "$log"
  elif [ "${CURL_RESULT}" -eq 400 ]; then
    echo bad request "$*" | tee -a "$log"
  elif [ "${CURL_RESULT}" -eq 401 ]; then
    echo unauthorized "$*" | tee -a "$log"
  elif [ "${CURL_RESULT}" -eq 403 ]; then
    echo forbidden "$*" | tee -a "$log"
  elif [ "${CURL_RESULT}" -eq 404 ]; then
    echo not found "$*" | tee -a "$log"
  elif [ "${CURL_RESULT}" -eq 409 ]; then
    echo conflict "$*" | tee -a "$log"
  else
    echo error "$*" | tee -a "$log"
  fi
}

function copy() {
  local log

  setActivity
  setLog
  cat "$log" >>"$ROOT_DIR/$ACTIVITY/$DATE/apigee.log"
  (
    cd "$ROOT_DIR/$CONTEXT/$ACTIVITY/$DATE" || return
    mkdir -p "$ROOT_DIR/$ACTIVITY/$DATE/$CONTEXT"
    cp -r ./* "$ROOT_DIR/$ACTIVITY/$DATE/$CONTEXT"
  )
}

function compress() {
  setActivity
  (
    cd "$ACTIVITY" || return
    7z a -r "${CONTEXT^^}_$DATE".zip "./$DATE/*" >/dev/null
    echo "$DATE" >>'list.txt'
    rm -rf "$DATE"
  )
}

function setPeriod() {
  cd "$ROOT_DIR/backup" || return
  PERIOD=$(ls -t *.zip | head -1)
  [[ -f 'list.txt' ]] && PERIOD=$(tail -n 1 'list.txt')
}

function extractContextBackup() {
  cd "$ROOT_DIR/$CONTEXT/backup" || return
  if [[ -z "$PERIOD" ]]; then
    PERIOD=$(ls -t *.zip | head -1)
    [[ -f 'list.txt' ]] && PERIOD=$(tail -n 1 'list.txt')
  fi
  7z x "${CONTEXT^^}_$PERIOD.zip" -aoa -o"$PERIOD" >/dev/null
}
