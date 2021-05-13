#!/usr/bin/env bash

VERB='GET'
export VERB
export ELEMENTS
export SUB_ELEMENTS

function setFile() {
  backup_dir="backup/$DATE"
  [[ "$ORG" ]] && backup_dir+="/$ORG"
  [[ "$ENV" ]] && backup_dir+="/$ENV"

  file="$backup_dir/$CONTEXT"
  [[ "$type" ]] && file+="_$type"
}

function setElements() {
  local query

  query='.[]'
  if [[ "$CONTEXT" == 'users' ]]; then
    query='.user[].name'
  fi
  elements=$(echo "$ELEMENTS" | jq "$query" | sed 's/\"//g')
}

function setRevisions() {
  local revision_dir
  local revisions
  local revision_max
  local rev
  local uri
  local current_uri
  local backup_dir
  local upload_dir

  if [[ "$CONTEXT" == 'sharedflows' ]] || [[ "$CONTEXT" == 'apis' ]]; then
    uri="$1"
    current_uri="$1"
    revisions=$(echo "$SUB_ELEMENTS" | jq '.revision[]' | sed 's/\"//g')
    IFS=$'\n'
    revision_max=$(echo "${revisions[*]}" | sort -nr | head -n1)
    revision_dir="$ROOT_DIR/revisions/$CONTEXT/$ORG/$element"
    backup_dir="$ROOT_DIR/$CONTEXT/backup/$DATE/$ORG/revisions/$element"
    upload_dir="$ROOT_DIR/uploads/$CONTEXT/$ORG"
    mkdir -p "$revision_dir"
    mkdir -p "$backup_dir"
    mkdir -p "$upload_dir"

    for revision in $revisions; do
      rev=$(printf "%06d" "$revision")
      if [[ ! -f "$revision_dir/revision_${rev}.zip" ]]; then
        uri+="/revisions/${revision}"
        makeCurl
        cp "$TEMP" "$backup_dir/revision_${rev}.json"
        status "$CURL_RESULT backup ${CONTEXT^^} done see backup/$DATE/$ORG/revisions/$element/revision_${rev}.json"

        uri+="?format=bundle"
        makeCurl
        cp "$TEMP" "$revision_dir/revision_${rev}.zip"
        status "$CURL_RESULT backup ${CONTEXT^^} revision done see revision/$element/revision_${rev}.zip"
      fi

      if [[ $revision == "$revision_max" ]]; then
        cp "$TEMP" "$upload_dir/${element}_rev${revision}_$(TZ=GMT date +"%Y_%m_%d").zip"
      fi

      uri="$current_uri"
    done
  fi
}

function makeBackupList() {
  local file
  local type
  local uri
  local backup_dir

  uri="$1"
  type="$2"
  setFile

  mkdir -p "$backup_dir"
  makeCurl
  status "$CURL_RESULT backup ${CONTEXT^^} done see $file".json
  ELEMENTS=$(jq '.' <"$TEMP")
  echo "$ELEMENTS" >"$file".json
  setFileContext
}

function makeBackupSub() {
  local type
  local file
  local uri
  local current_uri
  local backup_dir
  local elements

  uri="$1"
  current_uri="$1"
  type="$2"

  setElements
  for element in $elements; do
    uri+="/$element"

    setFile
    if [[ "$type" ]]; then
      uri+="/$type"
      backup_dir+="/$type"
    fi

    mkdir -p "$backup_dir"
    file="$backup_dir/$element"
    makeCurl
    status "$CURL_RESULT backup ${CONTEXT^^} done see $file".json
    uri="$current_uri"
    SUB_ELEMENTS=$(jq '.' <"$TEMP")
    echo "$SUB_ELEMENTS" >"$file".json
    setRevisions "$uri/$element"
  done
}
