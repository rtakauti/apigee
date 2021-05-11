#!/usr/bin/env bash

function setContext() {
  CONTEXT=$(basename "$(pwd)")
}

function setActivity() {
  ACTIVITY="$(echo "${0##*/}" | cut -d'_' -f1)"
}

function makeDir() {
  setContext
  setActivity
  BACKUP_DIR="$ROOT_DIR/backup/$DATE"
  RECOVER_DIR="$ROOT_DIR/recover/$DATE"
  RECOVER="$ROOT_DIR/recover"
  UPDATE_DIR="$ROOT_DIR/update/$DATE"
  DELETE_DIR="$ROOT_DIR/delete/$DATE"
  REMOVE="$ROOT_DIR/remove"
  CREATE_DIR="$ROOT_DIR/create/$DATE"
  ACTIVITY_DIR="$ACTIVITY/$DATE/$ORG"
  SUFFIX="${CONTEXT}_$ORG"
  LOG="$ACTIVITY/$DATE/$ORG/${CONTEXT}_log.txt"

  if [[ "$CONTEXT" == 'apigee' ]]; then
    ACTIVITY_DIR="$ACTIVITY/$DATE"
    SUFFIX="$CONTEXT"
    LOG="$ACTIVITY/$DATE/${CONTEXT}_log.txt"
  elif [[ "$CONTEXT" == 'organizations' ]] || [[ "$CONTEXT" == 'users' ]]; then
    ACTIVITY_DIR="$ACTIVITY/$DATE"
    SUFFIX="$CONTEXT"
  fi

  if [[ -n $ENV ]]; then
    ACTIVITY_DIR="$ACTIVITY_DIR/$ENV"
    SUFFIX="${SUFFIX}_$ENV"
  fi

  mkdir -p "$ACTIVITY_DIR"

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

  if [[ "$ACTIVITY" == 'backup' ]]; then
    (
      cd "$RECOVER" || return
      7z a -r "RECOVER_$DATE".zip "./$DATE/*.txt" >/dev/null
      rm -rf "$DATE"
    )
  fi
}
