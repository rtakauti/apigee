#!/usr/bin/env bash

VERB='GET'
export VERB
export LIST
export ITEM

function setFile() {
  backup_dir="backup/$DATE"
  [[ "$ORG" ]] && backup_dir+="/$ORG"
  [[ "$ENV" ]] && backup_dir+="/$ENV"
  if [[ "$type" ]] && [[ "$type" != 'list' ]] && [[ "$type" != 'expand' ]]; then
    backup_dir+="/$type"
  fi

  file="$CONTEXT"
  [[ "$type" ]] && file+="_$type"
  [[ "$element" ]] && file="$element"
  [[ "$element" ]] && [[ "$CONTEXT" == 'apps' ]] && file="$(jq '.name' "$TEMP" | sed 's/\"//g')"
  [[ "$type" ]] && [[ "$element" ]] && [[ "$CONTEXT" == 'apps' ]] && file="apps_$type"
}

function setElements() {
  local query

  query='.[]'
  if [[ "$CONTEXT" == 'users' ]]; then
    query='.user[].name'
  fi
  elements=$(echo "$LIST" | jq "$query" | sed 's/\"//g' | sed 's/ //g')
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

  if [[ -z "$type" ]] && { [[ "$CONTEXT" == 'sharedflows' ]] || [[ "$CONTEXT" == 'apis' ]]; }; then
    uri="$1"
    current_uri="$1"
    revisions=$(echo "$ITEM" | jq '.revision[]' | sed 's/\"//g')
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
  local type
  local uri
  local items

  uri="$1"
  type="$2"

  makeCurl
  setFile
  status "$CURL_RESULT backup ${CONTEXT^^} done see $backup_dir/$file".json
  items=$(jq '.' "$TEMP")
  mkdir -p "$backup_dir"
  echo "$items" >"$backup_dir/$file".json
  setFileContext "$items"
  [[ "$type" == 'list' ]] && LIST="$items"
}

function makeBackupSub() {
  local type
  local uri
  local current_uri
  local elements
  local element

  uri="$1"
  current_uri="$1"
  type="$2"

  setElements
  for element in $elements; do
    uri+="/$element"

    if [[ "$type" ]]; then
      uri+="/$type"
    fi

    makeCurl
    uri="$current_uri"
    setFile
    status "$CURL_RESULT backup ${CONTEXT^^} done see $backup_dir/$file".json
    ITEM=$(jq '.' "$TEMP")
    mkdir -p "$backup_dir"
    echo "$ITEM" >"$backup_dir/$file".json
    setRevisions "$uri/$element"
  done
}
