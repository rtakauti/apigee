#!/usr/bin/env bash

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
      --data "$DATA" &
    wait
  )
}

function makeCurlObject() {
  local specify

  specify="$1"
  makeCurl "/${object_uri}${specify}"
}

function makeCurlList() {
  export LIST

  LIST=$(echo "$payload" | jq '.[]' | sed 's/\"//g')

  if [[ "$CONTEXT" == 'organizations' ]]; then

    echo "$payload" | jq 'map(.+"|not_delete") | .[]' | sed 's/\"//g' >"$REMOVE/$SUFFIX.txt"
    printf "export ORGS=(%s)\n" "$(echo "$payload" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g')" >"$ROOT_DIR/organizations.sh"

  elif [[ "$CONTEXT" == 'environments' ]]; then

    echo "$payload" | jq 'map(.+"|not_delete") | .[]' | sed 's/\"//g' >"$REMOVE/$SUFFIX.txt"
    read -r -d '' environments <<'EOF'
#!/usr/bin/env bash


#TROCAR

export ENVS

EOF
    if [[ -f "$ROOT_DIR/environments.sh" ]]; then
      environments=$(cat "$ROOT_DIR/environments.sh")
    fi

    elements="$ORG $(echo "$payload" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g' | sed 's/\"//g')"
    if [[ "$environments" != *"$elements"* ]]; then
      printf 'if [[ "$ORG" == '%s' ]]; then' "$ORG" >"$TEMP"
      printf "\nENVS=(%s)\n" "$(echo "$payload" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g')" >>"$TEMP"
      printf "fi\n" >>"$TEMP"

      if ! [[ "$environments" == *"$elements"* ]]; then
        echo "$environments" | sed $'/#TROCAR/{e cat $TEMP\n}' >"$ROOT_DIR/environments.sh"
        echo '#' "$elements" >>"$ROOT_DIR/environments.sh"
      fi

    fi
  elif [[ "$CONTEXT" == 'users' ]]; then
    LIST=$(echo "$payload" | jq '.user[].name' | sed 's/\"//g')
    echo "$payload" | jq '[.user[].name]' | jq 'map(.+"|not_delete") | .[]' | sed 's/\"//g' >"$REMOVE/$SUFFIX.txt"
  fi
}

function makeBackupList() {
  local file
  local jq_query
  local environments
  local elements

  VERB='GET'
  URI="$1"
  type="$2"
  jq_query="$3"
  FILENAME="$ACTIVITY_DIR/$CONTEXT"
  file="$FILENAME.json"

  if [[ -n "$type" ]]; then
    file="${FILENAME}_${type}.json"
  fi

  makeCurl
  status "$CURL_RESULT backup ${CONTEXT^^} done see $file"
  payload=$(jq <"$TEMP")
  echo "$payload" >"$file"

  if [[ -z "$payload" ]]; then
    echo 'no items found' | tee -a "$LOG"
    return
  fi

  if [[ "$type" == 'list' ]]; then
    makeCurlList
  elif [[ "$type" == 'jq' ]]; then
    LIST=$(echo "$payload" | jq "$jq_query" | sed 's/\"//g')
  fi
}

function makeBackupSub() {
  local sub_file
  local sub_uri
  local object
  local object_uri
  local sub_object
  local payload
  local payload1
  local revision_dir
  local name
  local revision_max
  local revisions
  local rev
  local jq_query
  local jq_query_sub

  if [[ -z "$LIST" ]]; then
    return
  fi

  URI="$1"
  ACTION="$2"
  SUB_ACTION="$3"
  name='name'

  if [[ "$CONTEXT" == 'developers' ]] || [[ "$CONTEXT" == 'users' ]]; then
    name='email'
  fi

  for object in $LIST; do

    sub_file="$ACTIVITY_DIR/${object}"
    if [[ -n "$SUB_ACTION" ]]; then
      mkdir -p "$ACTIVITY_DIR/$SUB_ACTION"
      sub_file="$ACTIVITY_DIR/$SUB_ACTION/${object}_$SUB_ACTION"
      sub_uri="/$SUB_ACTION"
      sub_object="_$SUB_ACTION"
      FILENAME="$ACTIVITY_DIR/$SUB_ACTION/${CONTEXT}_$SUB_ACTION"
    fi

    if [[ "$type" == 'jq' ]]; then
      IFS='|' read -ra object <<<"$object"
      sub_file="$ACTIVITY_DIR/${object[1]}"
    fi

    object_uri="${object// /%20}"
    makeCurlObject "$sub_uri"
    status "$CURL_RESULT backup ${CONTEXT^^} done see $sub_file.json"

    jq_query='.'
    if [[ "$CONTEXT" == 'apps' ]]; then
      jq_query='.credentials[].consumerKey = "*******" | .credentials[].consumerSecret = "*******"'
    fi

    payload=$(cat <"$TEMP" | jq "$jq_query")

    if [[ "$ACTION" == 'list' ]]; then
      (
        cd "$ACTIVITY_DIR/$SUB_ACTION" || return
        jq_query_sub='.[]'
        if [[ "$SUB_ACTION" == 'developers' ]]; then
          jq_query_sub='.developer[].email'
        fi
        elements=$(echo "$payload" | jq "$jq_query_sub" | sed 's/\"//g')
        IFS=$'\n'
        for element in $elements; do
          makeCurlObject "/$SUB_ACTION/$element"
          jq_query_sub='.'
          if [[ "$SUB_ACTION" == 'apps' ]]; then
            jq_query_sub='.credentials[].consumerKey = "*******" | .credentials[].consumerSecret = "*******"'
          fi
          payload1=$(cat <"$TEMP")
          if [[ "$payload1" ]]; then
            echo "$payload1" | jq "$jq_query_sub" >"${object}_${SUB_ACTION}_$element.json"
          fi
        done
      )
      sub_file="$ACTIVITY_DIR/$SUB_ACTION/${object}_${SUB_ACTION}_list"
    fi

    [[ -n $(echo "$payload" | sed 's/[][]//g') ]] && echo "$payload" >"$sub_file.json"
    status "$CURL_RESULT backup ${CONTEXT^^} done see $sub_file.json"

    if [[ "$ACTION" == 'revision' ]]; then

      revisions=$(echo "$payload" | jq '.revision[]' | sed 's/\"//g')
      IFS=$'\n'
      revision_max=$(echo "${revisions[*]}" | sort -nr | head -n1)

      for revision in $revisions; do
        revision_dir="$ROOT_DIR/revisions/$CONTEXT/$ORG/$object"
        mkdir -p "$revision_dir"
        rev=$(printf "%06d" "$revision")
        (
          cd "$revision_dir" || return
          if [[ ! -f "$revision_dir/revision_${rev}.zip" ]]; then
            makeCurlObject "/revisions/${revision}?format=bundle"
            cp "$TEMP" "$revision_dir/revision_${rev}.zip"
          fi
        )
        mkdir -p "$ROOT_DIR/uploads/$CONTEXT/$ORG"

        if [[ $revision == "$revision_max" ]]; then
          cp "$TEMP" "$ROOT_DIR/uploads/$CONTEXT/$ORG/${object}_rev${revision}_$(TZ=GMT date +"%Y_%m_%d").zip"
        fi

        status "$CURL_RESULT backup ${CONTEXT^^} revision done see revision/$object"
      done
    fi

    if [[ -z "$SUB_ACTION" ]]; then
      payload=$(echo "$payload" | jq -c '. |  del(.createdAt,.createdBy,.lastModifiedAt,.lastModifiedBy,.organization,.apps,.metaData,.revision)' 2>/dev/null)
      [[ "$payload" ]] && echo "$payload" >>"$FILENAME.txt"
      paste -d "|" <(echo "$payload" | jq --arg name "$name" '.[$name]' | sed 's/\"//g') <(echo "$payload" | jq -c 'del(.name,.status)') >>"${FILENAME}_change.txt"
    else
      payload=$(echo "$payload" | jq -c '.')
      [[ "$payload" ]] && echo "$payload" >>"$FILENAME.txt"
      [[ "$payload" ]] && echo "$payload" | jq -c '.' >>"${FILENAME}${sub_object}_change.txt"
    fi

    if [[ "$ACTION" == 'status' ]]; then
      paste -d "|" <(echo "$payload" | jq --arg name "$name" '.[$name]' | sed 's/\"//g') <(echo "$payload" | jq '.status' | sed 's/\"//g') >>"${FILENAME}_status.txt"
    fi

  done

  cp "$FILENAME.txt" "$RECOVER/$SUFFIX.txt"
  cp "$FILENAME.txt" "$RECOVER_DIR/$SUFFIX.txt"

  if [[ "$ACTION" == 'status' ]]; then
    mv "${FILENAME}_status.txt" "$ROOT_DIR/change/${SUFFIX}_status.txt"
  fi

  if [[ -n "$SUB_ACTION" ]]; then
    mv "${FILENAME}${sub_object}_change.txt" "$ROOT_DIR/change/${SUFFIX}${sub_object}_change.txt"
  elif [[ "$CONTEXT" != 'apis' ]] && [[ "$CONTEXT" != 'sharedflows' ]]; then
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
  CONTENT_TYPE='Content-Type: application/json'

  if [[ ! -f "$object_file" ]]; then
    echo 'recover file not found' | tee -a "$LOG"
    return
  fi

  cp "$object_file" "$ACTIVITY_DIR/$CONTEXT.txt"
  while IFS= read -r object; do
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
