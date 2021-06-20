#!/usr/bin/env bash

VERB='GET'
export VERB
export LIST
export ELEMENT

function setFile() {
  backup_dir="backup/$DATE"
  [[ "$ORG" ]] && backup_dir+="/$ORG"
  [[ "$ENV" ]] && backup_dir+="/$ENV"
  if [[ "$type" ]] && [[ "$type" != 'EXPANDED' ]]; then
    backup_dir+="/$type"
  fi

  file="$CONTEXT"
  [[ "$type" ]] && file+="_$type"
  [[ "$element" ]] && file="$element"
  [[ "$type" == 'EXPANDED' ]] && file='EXPANDED'
}

function createResourceFile() {
  local URI
  local sub_uri
  local file
  local type_resource
  local name_resource
  local resource_dir
  local check
  declare -A checksum=(
    [3ffe49caefcb137c63880033891af35f]='.resourceFile[]'
  )

  if [[ -z "$type" ]] && { [[ "$CONTEXT" == 'organizations' ]] || [[ "$CONTEXT" == 'environments' ]]; }; then
    sub_uri="$1"
    URI="$1"

    makeCurl
    check=$(md5sum "$TEMP" | awk '{ print $1 }')
    [[ -n "${checksum[$check]}" ]] && return
    resource_dir="$ROOT_DIR/$CONTEXT/backup/$DATE"
    [[ "$ORG" ]] && resource_dir+="/$ORG"
    [[ "$ENV" ]] && resource_dir+="/$ENV"
    resource_dir+='/resourcefiles'
    mkdir -p "$resource_dir/$element"
    jq '.' "$TEMP" >"$resource_dir/$element.json"
    status "$CURL_RESULT backup ${CONTEXT^^} done see backup/$DATE/resourcefiles/$element.json"
    for file in $(jq -c '.resourceFile[]' "$resource_dir/$element.json"); do
      type_resource=$(echo "$file" | jq '.type' | sed 's/\"//g')
      name_resource=$(echo "$file" | jq '.name' | sed 's/\"//g')
      URI+="/$type_resource/$name_resource"
      makeCurl
      cp "$TEMP" "$resource_dir/$element/$name_resource"
      status "$CURL_RESULT backup ${CONTEXT^^} done see backup/$DATE/resourcefiles/$element/$name_resource"
      URI="$sub_uri"
    done
  fi
}

function createRevisions() {
  local revisions
  local rev
  local URI
  local current_uri
  local copy_uri
  local backup_dir
  declare -a actions=(
    revision
    bundle
    upload
    policy
    deployment
    resource
  )

  if [[ -z "$type" ]] && { [[ "$CONTEXT" == 'sharedflows' ]] || [[ "$CONTEXT" == 'apis' ]]; }; then

    function revision() {
      makeCurl
      jq '.' "$TEMP" >"$backup_dir/revision_${rev}.json"
      status "$CURL_RESULT backup ${CONTEXT^^} done see backup/$DATE/$ORG/$element/revision_${rev}.json"
    }

    function bundle() {
      local revision_dir

      URI+="?format=bundle"
      makeCurl
      revision_dir="$ROOT_DIR/revisions/$CONTEXT/$ORG/$element"
      mkdir -p "$revision_dir"
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

    #
    # Implemented API deployments in deployments module
    #
    function deployment() {
      local env_quantity
      local name

      if [[ "$CONTEXT" != 'apis' ]]; then
        URI+="/deployments"
        makeCurl
        name='deploy_'
      env_quantity=$(jq '.environment | length' "$TEMP")
      if [[ $env_quantity != 0 ]]; then
        env_quantity=$((env_quantity - 1))
        for env in $(seq 0 "$env_quantity"); do
          name+="$(jq ".environment[$env].name" "$TEMP" | sed 's/\"//g')_"
        done
          jq '.' "$TEMP" >"$backup_dir/$name${rev}.json"
        fi
        status "$CURL_RESULT backup ${CONTEXT^^} done see backup/$DATE/$ORG/$element/deploy_${rev}.json"
      fi
    }

    function resource() {
      local resource_dir
      local type
      local name
      local sub_uri
      local check
      declare -A checksum=(
        [3ffe49caefcb137c63880033891af35f]='.resourceFile[]'
      )

      URI+="/resourcefiles"
      sub_uri="$URI"
      makeCurl
      check=$(md5sum "$TEMP" | awk '{ print $1 }')
      [[ -n "${checksum[$check]}" ]] && return
      resource_dir="$ROOT_DIR/$CONTEXT/backup/$DATE/$ORG"
      mkdir -p "$resource_dir/$element/resourcefiles/revision_${rev}"
      items=$(jq -c '.resourceFile[]' "$TEMP")
      for item in $items; do
        type=$(echo "$item" | jq '.type' | sed 's/\"//g')
        name=$(echo "$item" | jq '.name' | sed 's/\"//g')
        URI+="/$type/$name"
        makeCurl
        cp "$TEMP" "$resource_dir/$element/resourcefiles/revision_${rev}/$name"
        status "$CURL_RESULT backup ${CONTEXT^^} done see backup/$DATE/$ORG/$element/resourcefiles/revision_${rev}/$name"
        URI="$sub_uri"
      done
    }

    function policy() {
      local policy_dir
      local items
      local sub_uri
      local check
      declare -A checksum=(
        [6b75a2a98c1aedf4e31f430cc178207f]=1
      )

      URI+="/policies"
      sub_uri="$URI"
      makeCurl
      check=$(md5sum "$TEMP" | awk '{ print $1 }')
      [[ -n "${checksum[$check]}" ]] && return
      policy_dir="$ROOT_DIR/$CONTEXT/backup/$DATE/$ORG"
      mkdir -p "$policy_dir/$element/policies/revision_${rev}"
      items=$(jq '.[]' "$TEMP" | sed 's/\"//g')
      for item in $items; do
        URI+="/$item"
        makeCurl
        jq '.' "$TEMP" >"$policy_dir/$element/policies/revision_${rev}/$item.json"
        status "$CURL_RESULT backup ${CONTEXT^^} done see backup/$DATE/$ORG/policies/$element/revision_${rev}/$item.json"
        URI="$sub_uri"
      done
    }

    function audit() {
      local URI
      local check
      declare -A checksum=(
        [c03a0890b83c8fe0fc9606ba70f688cc]='.auditRecord[]'
      )

      URI="audits/organizations/$ORG/$CONTEXT/$element?expand=true&startTime=1500000000000&endTime=1800000000000"
      makeCurl
      check=$(md5sum "$TEMP" | awk '{ print $1 }')
      [[ -n "${checksum[$check]}" ]] && return
      jq '[.auditRecord[] | . + {date: (.timeStamp / 1000 | strftime("%Y-%m-%d %H:%M:%S UTC"))}]' "$TEMP" >"$backup_dir/audits.json"
      status "$CURL_RESULT backup ${CONTEXT^^} done see backup/$DATE/$ORG/$element/audit.json"
    }

    current_uri="$1"
    revisions=$(echo "$ELEMENT" | jq '.revision[]' | sed 's/\"//g')
    IFS=$'\n'
    backup_dir="$ROOT_DIR/$CONTEXT/backup/$DATE/$ORG/$element"
    mkdir -p "$backup_dir"
    mv "$backup_dir.json" "$backup_dir/$element.json"
    for action in "${actions[@]}"; do
      for revision in $revisions; do
        rev=$(printf "%06d" "$revision")
        copy_uri=${current_uri/item/$revision}
        URI="$copy_uri"
        $action
      done
    done
    audit
  fi
}

function makeBackupList() {
  local backup_dir
  local type
  local URI
  local items
  local check
  declare -A checksum=(
    [fa9497f5acccafcc3e6019657bdc5eb1]=1
    [9340db01545709694e12c770b59efff5]=1
  )
  unset LIST

  URI="$1"
  type="$2"

  makeCurl
  check=$(md5sum "$TEMP" | awk '{ print $1 }')
  [[ -n "${checksum[$check]}" ]] && return
  setFile
  status "$CURL_RESULT backup ${CONTEXT^^} done see $backup_dir/$file".json
  items=$(jq '.' "$TEMP")
  mkdir -p "$backup_dir"
  echo "$items" >"$backup_dir/$file".json
  createInitializationFile "$items"
}

function makeBackupSub() {
  local backup_dir
  local type
  local URI
  local current_uri
  local element
  local check
  declare -A checksum=(
    [fa9497f5acccafcc3e6019657bdc5eb1]=1
    [e44aaaf3aa0096b0e143f86af459c63b]=1
    [82c0ba3ab6ead021e5521df1a0e3fe70]=1
    [3ffe49caefcb137c63880033891af35f]='.resourceFile[]'
    [d41d8cd98f00b204e9800998ecf8427e]='empty'
  )
  current_uri="$1"
  type="$2"

  backup_dir="backup/$DATE"
  [[ "$ORG" ]] && backup_dir+="/$ORG"
  [[ "$ENV" ]] && backup_dir+="/$ENV"
  [[ ! -f "$backup_dir/$CONTEXT.json" ]] && return
  LIST=$(cat <"$backup_dir/$CONTEXT.json")
  for element in $(echo "$LIST" | jq '.[]' | sed 's/\"//g'); do
    URI=${current_uri/element/"$element"}
    [[ "$type" ]] && URI=$URI/$type

    makeCurl
    check=$(md5sum "$TEMP" | awk '{ print $1 }')
    [[ -n "${checksum[$check]}" ]] && continue
    setFile
    status "$CURL_RESULT backup ${CONTEXT^^} done see $backup_dir/$file".json
    ELEMENT=$(jq '.' "$TEMP")
    mkdir -p "$backup_dir"
    echo "$ELEMENT" >"$backup_dir/$file".json
    createRevisions "$URI/revisions/item"
    createResourceFile "$URI/resourcefiles"
  done
}

function makeBackupSubItem() {
  local backup_dir
  local URI
  local pre_uri
  local current_uri
  local query
  local type
  local detail
  local extension
  local check
  local element
  declare -A checksum=(
    [00eccebe0939574546663ae329e41029]=1
    [45249e4154128f693760143690cf86f1]=1
    [d41d8cd98f00b204e9800998ecf8427e]=1
  )

  current_uri="$1"
  type="$2"
  detail="$3"

  setFile
  [[ ! -d "$backup_dir" ]] && return
  for element in $(echo "$LIST" | jq '.[]' | sed 's/\"//g'); do
    pre_uri=${current_uri/element/"$element"}
    [[ ! -f "$backup_dir/$element".json ]] && continue
    query='.[]'
    IFS='/' read -ra endpoints <<<"$current_uri"
    for endpoint in "${endpoints[@]}"; do
      if [[ "$endpoint" == 'entries' ]]; then
        query='.entry[].name'
        break
      fi
    done
    items=$(jq "$query" "$backup_dir/$element".json | sed 's/\"//g' | sed 's/ //g')
    for item in $items; do
      URI=${pre_uri/item/"$item"}

      makeCurl
      check=$(md5sum "$TEMP" | awk '{ print $1 }')
      [[ -n "${checksum[$check]}" ]] && continue
      mkdir -p "$backup_dir/$element"
      (
        cd "$backup_dir/$element" || return
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
      )
    done
  done
}
