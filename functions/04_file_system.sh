#!/usr/bin/env bash

function createInitializationFile() {
  local items
  local elements
  local environments

  items="$1"
  if [[ "$CONTEXT" == 'organizations' ]]; then

    printf "export ORGS=(%s)\n" "$(echo "$items" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g')" >"$ROOT_DIR/organizations.sh"

  elif [[ "$CONTEXT" == 'environments' ]]; then

    read -r -d '' environments <<'EOF'
#!/usr/bin/env bash

#TROCAR

export ENVS

EOF
    [[ -f "$ROOT_DIR/environments.sh" ]] && environments=$(cat "$ROOT_DIR/environments.sh")

    elements="$ORG $(echo "$items" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g' | sed 's/\"//g')"
    if [[ "$environments" != *"$elements"* ]]; then
      printf 'if [[ "$ORG" == '%s' ]]; then' "$ORG" >"$TEMP"
      printf "\nENVS=(%s)\n" "$(echo "$items" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g')" >>"$TEMP"
      printf "fi\n" >>"$TEMP"
      echo "$environments" | sed $'/#TROCAR/{e cat $TEMP\n}' >"$ROOT_DIR/environments.sh"
      echo '#' "$elements" >>"$ROOT_DIR/environments.sh"
    fi
  fi
}

function rearrangeFolder() {
  local list
  local backup_dir

  backup_dir="backup/$DATE"
  [[ "$ORG" ]] && backup_dir+="/$ORG"
  list="$backup_dir/_LIST.json"
  [[ ! -f "$list" ]] && return
  list=$(jq '.[]' "$list" | sed 's/\"//g')
  (
    cd "$backup_dir" || return
    for folder in */; do
      for element in $list; do
        [[ -d "$folder" ]] && mkdir -p "$element" && mv "${folder%?}/$element.json" "$element/${element}_${folder%?}.json"
      done
      [[ -d "$folder" ]] && rm -rf "$folder"
    done
    for element in $list; do
      [[ -d "$element" ]] || ([[ ! -d "$element" ]] && mkdir -p "$element") && mv "$element.json" "$element/$element.json"
    done
  )
}

function execution(){
    local upload_dir
    local file_shell

    upload_dir="$ROOT_DIR/uploads/$CONTEXT/$ORG"
    file_shell="$upload_dir/${ORG}_apis.sh"

    mkdir -p "$upload_dir"
    list=$(jq .[] "backup/$DATE/$ORG/$CONTEXT.json" | sed 's/"//g')
    echo "$list" >"$upload_dir/${ORG}_apis.txt"
    printf "$list" >"$TEMPO"

    read -r -d '' deploy <<'EOF'
#!/usr/bin/env bash

export USERNAME=email
export PASSWORD=password

export URL=http://example.com
export PLANET=dev

declare -a apis=(
#TROCAR
)


function upload(){

    if [[ -z "$api" ]] ; then
        api="$1"
        if [[ -d "$api" ]]; then
            cd "$api" || exit
        fi
    fi

    curl -i -X POST "$URL/v1/organizations/#ORG/apis?action=import&name=$api" \
    --user "$USERNAME:$PASSWORD" \
    --header 'Content-Type: application/octet-stream' \
    -T "$PLANET.zip"
}

function deploy(){
    local env
    local rev

    env="$1"
    if [[ -z "$api" ]] ; then
        api="$2"
    fi

    rev=$(echo $(curl --silent --request GET "$URL/v1/organizations/#ORG/apis/$api/revisions" \
    --user "$USERNAME:$PASSWORD") | jq .[] | sed 's/"//g' | sort -nr | head -n1)

    curl -i -X POST "$URL/v1/organizations/#ORG/environments/$env/apis/$api/revisions/$rev/deployments?override=true" \
    --user "$USERNAME:$PASSWORD" \
    --header 'Content-Type: application/x-www-form-urlencoded'
}


function release(){
    local env

    env="$1"
    if [[ -z "$api" ]] ; then
        api="$2"
    fi

    upload "$api"
    deploy "$env" "$api"
}


function undeploy(){
    local env
    local revisions

    env="$1"
    if [[ -z "$api" ]] ; then
        api="$2"
    fi

    revisions=$(echo $(curl --silent --request GET "$URL/v1/organizations/#ORG/apis/$api/revisions" \
    --user "$USERNAME:$PASSWORD") | jq '.[]' | sed 's/"//g')

    for revision in $revisions; do
        curl --request DELETE "$URL/v1/organizations/#ORG/environments/$env/apis/$api/revisions/$revision/deployments" \
        --user "$USERNAME:$PASSWORD"
    done

}

function remove(){
    local environments

    if [[ -z "$api" ]] ; then
        api="$1"
    fi

    environments=$(echo $(curl --silent --request GET "$URL/v1/organizations/#ORG/environments" \
    --user "$USERNAME:$PASSWORD") | jq '.[]' | sed 's/"//g')

    for environment in $environments; do
        undeploy "$environment" "$api"
    done

    curl --request DELETE "$URL/v1/organizations/#ORG/apis/$api" \
    --user "$USERNAME:$PASSWORD"
}


function mass(){
    local action

    action="$1"
    IFS=$'\n'
    for api in "${apis[@]}"; do
        if [[ -d "$api" ]]; then
            (
                cd "$api" || exit
                "$action" "${@:2}"
            )
        fi
    done
}

"$1" "${@:2}"

EOF

    echo "$deploy" | sed $'/#TROCAR/{e cat $TEMPO\n}' >"$file_shell"
    sed -i 's/#TROCAR//' "$file_shell"
    sed -i 's/#ORG/'"$ORG"'/' "$file_shell"
}