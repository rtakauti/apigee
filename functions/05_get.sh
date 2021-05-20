#!/usr/bin/env bash

VERB='GET'
export VERB
export LIST
export ELEMENT

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
  local revisions
  local rev
  local uri
  local current_uri
  local copy_uri

  if [[ -z "$type" ]] && { [[ "$CONTEXT" == 'sharedflows' ]] || [[ "$CONTEXT" == 'apis' ]]; }; then
    current_uri="$1"
    revisions=$(echo "$ELEMENT" | jq '.revision[]' | sed 's/\"//g')
    IFS=$'\n'

    function revision() {
      local backup_dir

      backup_dir="$ROOT_DIR/$CONTEXT/backup/$DATE/$ORG/revisions/$element"
      mkdir -p "$backup_dir"
      makeCurl
      cp "$TEMP" "$backup_dir/revision_${rev}.json"
      status "$CURL_RESULT backup ${CONTEXT^^} done see backup/$DATE/$ORG/revisions/$element/revision_${rev}.json"
    }

    function bundle() {
      local revision_dir

      revision_dir="$ROOT_DIR/revisions/$CONTEXT/$ORG/$element"
      mkdir -p "$revision_dir"
      uri+="?format=bundle"
      makeCurl
      cp "$TEMP" "$revision_dir/revision_${rev}.zip"
      status "$CURL_RESULT backup ${CONTEXT^^} revision done see revisions/$element/revision_${rev}.zip"
    }

    function upload() {
      local upload_dir
      local revision_max

      revision_max=$(echo "${revisions[*]}" | sort -nr | head -n1)
      if [[ $revision == "$revision_max" ]]; then
        upload_dir="$ROOT_DIR/uploads/$CONTEXT/$ORG"
        mkdir -p "$upload_dir"
        cp "$TEMP" "$upload_dir/${element}_rev${revision}_$(TZ=GMT date +"%Y_%m_%d").zip"
        status "$CURL_RESULT backup ${CONTEXT^^} last revision done see uploads/${element}_rev${revision}_$(TZ=GMT date +"%Y_%m_%d").zip"
      fi
    }

    function deployment() {
      local deployment_dir

      deployment_dir="$ROOT_DIR/$CONTEXT/backup/$DATE/$ORG/deployments/$element"
      mkdir -p "$deployment_dir"
      uri+="/deployments"
      makeCurl
      cp "$TEMP" "$deployment_dir/revision_${rev}.json"
      status "$CURL_RESULT backup ${CONTEXT^^} done see backup/$DATE/$ORG/deployments/$element/revision_${rev}.json"
    }

    function resource() {
      local resource_dir

      resource_dir="$ROOT_DIR/$CONTEXT/backup/$DATE/$ORG/resourcefiles/$element"
      mkdir -p "$resource_dir"
      uri+="/resourcefiles"
      makeCurl
      cp "$TEMP" "$resource_dir/revision_${rev}.json"
      status "$CURL_RESULT backup ${CONTEXT^^} done see backup/$DATE/$ORG/resourcefiles/$element/revision_${rev}.json"
    }

    for action in revision bundle upload deployment resource; do
      for revision in $revisions; do
        rev=$(printf "%06d" "$revision")
        copy_uri=${current_uri/item/$revision}
        uri="$copy_uri"
        $action
      done
    done
  fi
}

function makeBackupList() {
  local type
  local uri
  local items
  local query
  local check
  declare -A checksum=([fa9497f5acccafcc3e6019657bdc5eb1]=1 [9340db01545709694e12c770b59efff5]=1)
  unset LIST

  uri="$1"
  type="$2"

  makeCurl
  check=$(md5sum "$TEMP" | awk '{ print $1 }')
  [[ -n "${checksum[$check]}" ]] && return
  setFile
  status "$CURL_RESULT backup ${CONTEXT^^} done see $backup_dir/$file".json
  query='.'
  [[ "$CONTEXT" == 'reports' ]] && query='[[.qualifier[].name],[.qualifier[].displayName]] | transpose[] | .[0]+"|"+.[1]'
  items=$(jq "$query" "$TEMP")
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
  local check
  declare -A checksum=(
    [fa9497f5acccafcc3e6019657bdc5eb1]=1 [e44aaaf3aa0096b0e143f86af459c63b]=1 [82c0ba3ab6ead021e5521df1a0e3fe70]=1 [3ffe49caefcb137c63880033891af35f]=1
  )
  current_uri="$1"
  type="$2"

  [[ -z "$LIST" ]] && return
  setElements
  for element in $elements; do
    uri=${current_uri/element/"$element"}
    [[ "$type" ]] && uri=$uri/$type

    makeCurl
    check=$(md5sum "$TEMP" | awk '{ print $1 }')
    [[ -n "${checksum[$check]}" ]] && continue
    setFile
    status "$CURL_RESULT backup ${CONTEXT^^} done see $backup_dir/$file".json
    ELEMENT=$(jq '.' "$TEMP")
    mkdir -p "$backup_dir"
    echo "$ELEMENT" >"$backup_dir/$file".json
    setRevisions "$uri/revisions/item"
  done
}

function makeBackupSubItem() {
  local uri
  local pre_uri
  local current_uri
  local query
  local type
  local detail
  local extension

  current_uri="$1"
  type="$2"
  detail="$3"
  setFile
  [[ ! -d "$backup_dir" ]] && return
  (
    cd "$backup_dir" || return
    setElements
    for element in $elements; do
      if [[ -f "$element".json ]]; then
        query='.[]'
        IFS='/' read -ra endpoints <<<"$current_uri"
        for endpoint in "${endpoints[@]}"; do
          if [[ "$endpoint" == 'entries' ]]; then
            query='.entry[].name'
            break
          fi
        done
        items=$(jq "$query" "$element".json | sed 's/\"//g' | sed 's/ //g')
        mkdir -p "$element"
        (
          cd "$element" || return
          pre_uri=${current_uri/element/"$element"}
          for item in $items; do
            uri=${pre_uri/item/"$item"}

            makeCurl
            if [[ "$detail" ]]; then
              extension='json'
              { [[ "$detail" == 'certificate' ]] || [[ "$detail" == 'export' ]]; } && extension='pem'
              [[ "$detail" == 'csr' ]] && extension='csr'
              mkdir -p "$detail"
              cp "$TEMP" "$detail/$item.$extension"
              if [[ "$detail" == 'export' ]]; then
                (
                  cd "$detail" || return
                  openssl x509 -pubkey -noout -in "$item.$extension" >"$item.key"
                )
              fi
              status "$CURL_RESULT backup ${CONTEXT^^} done see $backup_dir/$element/$item/$detail/$item.$extension"
            else
              status "$CURL_RESULT backup ${CONTEXT^^} done see $backup_dir/$element/$item".json
              jq '.' "$TEMP" >"$item".json
            fi
          done
        )
      fi
    done
  )
}
