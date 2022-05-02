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

#CHANGE

export ENVS

EOF
    [[ -f "$ROOT_DIR/environments.sh" ]] && environments=$(cat "$ROOT_DIR/environments.sh")

    elements="$ORG $(echo "$items" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g' | sed 's/\"//g')"
    if [[ "$environments" != *"$elements"* ]]; then
      printf 'if [[ "$ORG" == '%s' ]]; then' "$ORG" >"$TEMP"
      printf "\nENVS=(%s)\n" "$(echo "$items" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g')" >>"$TEMP"
      printf "fi\n" >>"$TEMP"
      echo "$environments" | sed $'/#CHANGE/{e cat $TEMP\n}' >"$ROOT_DIR/environments.sh"
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


function apis_deploy(){
    read -r -d '' deploy <<'EOF'
#!/usr/bin/env bash

export USERNAME=email
export PASSWORD=password

export URL=http://example.com
export PLANET=dev

declare -a elements=(
#CHANGE
)

function create(){
    [[ -z "$element" ]] && element="$1"
    curl --include --request POST "$URL/v1/organizations/#ORG/apis" \
    --user "$USERNAME:$PASSWORD" \
    --header 'Content-Type: application/json' \
    --data-raw '{
        "name": "'"$element"'"
    }'
}

function upload(){
    if [[ -z "$element" ]] ; then
        element="$1"
        if [[ -d "$element" ]]; then
            (
                cd "$element"
                curl --include --request POST "$URL/v1/organizations/#ORG/apis?action=import&name=$element" \
                --user "$USERNAME:$PASSWORD" \
                --header 'Content-Type: application/octet-stream' \
                --upload-file "$PLANET.zip"
            )
            exit
        fi
    fi

    curl --include --request POST "$URL/v1/organizations/#ORG/apis?action=import&name=$element" \
    --user "$USERNAME:$PASSWORD" \
    --header 'Content-Type: application/octet-stream' \
    --upload-file "$PLANET.zip"
}

function deploy(){
    local env
    local revision

    env="$1"
    [[ -z "$element" ]] && element="$1"; env="$2"
    revision=$(echo $(curl --silent --request GET "$URL/v1/organizations/#ORG/apis/$element/revisions" \
    --user "$USERNAME:$PASSWORD") | jq .[] | sed 's/"//g' | sort -nr | head -n1)
    curl --include --request POST "$URL/v1/organizations/#ORG/environments/$env/apis/$element/revisions/$revision/deployments?override=true" \
    --user "$USERNAME:$PASSWORD" \
    --header 'Content-Type: application/x-www-form-urlencoded'
}

function release(){
    local env

    env="$1"
    [[ -z "$element" ]] && element="$1"; env="$2"
    upload
    deploy "$env"
}

function undeploy(){
    local env
    local revisions
    local revision

    env="$1"
    [[ -z "$element" ]] && element="$1"; env="$2"
    revisions=$(echo $(curl --silent --request GET "$URL/v1/organizations/#ORG/apis/$element/revisions" \
    --user "$USERNAME:$PASSWORD") | jq '.[]' | sed 's/"//g')
    for revision in $revisions; do
        curl --include --request DELETE "$URL/v1/organizations/#ORG/environments/$env/apis/$element/revisions/$revision/deployments" \
        --user "$USERNAME:$PASSWORD"
    done
}

function delete(){
    [[ -z "$element" ]] && element="$1"
    curl  --request DELETE "$URL/v1/organizations/#ORG/apis/$element" \
    --user "$USERNAME:$PASSWORD"
}

function remove(){
    local environments
    local environment

    [[ -z "$element" ]] && element="$1"
    environments=$(echo $(curl --silent --request GET "$URL/v1/organizations/#ORG/environments" \
    --user "$USERNAME:$PASSWORD") | jq '.[]' | sed 's/"//g')
    for environment in $environments; do undeploy "$environment" "$element"; done
    delete
}

function mass(){
    local action

    action="$1"
    IFS=$'\n'
    for element in "${elements[@]}"; do
        if [[ -d "$element" ]]; then
            (
                cd "$element"
                "$action" "${@:2}"
            )
        fi
    done
}

"$1" "${@:2}"

EOF
}


function apiproducts_deploy(){
    read -r -d '' deploy <<'EOF'
#!/usr/bin/env bash

export USERNAME=email
export PASSWORD=password

export URL=http://example.com
export PLANET=dev


declare -a elements=(
#CHANGE
)

function create(){
    if [[ -z "$element" ]] ; then
        element="$1"
        if [[ -d "$element" ]]; then
            cd "$element"
            data=$(cat <"$PLANET.json")
        fi
    fi
    curl --include --request POST "$URL/v1/organizations/#ORG/apiproducts" \
    --user "$USERNAME:$PASSWORD" \
    --header 'Content-Type: application/json' \
    --data-raw "$data"
}


function mass(){
    local action
    local data

    action="$1"
    IFS=$'\n'
    for element in "${elements[@]}"; do
        if [[ -d "$element" ]]; then
            (
                cd "$element"
                data=$(cat <"$PLANET.json")
                "$action" "${@:2}"
            )
        fi
    done
}

"$1" "${@:2}"

EOF
}


function companies_deploy(){
    local item

    for item in $list; do
        cp -r "backup/$DATE/$ORG/$item" "$ROOT_DIR/uploads/$CONTEXT/$ORG"
    done
    read -r -d '' deploy <<'EOF'
#!/usr/bin/env bash

export USERNAME=email
export PASSWORD=password

export URL=http://example.com
export PLANET=dev


declare -a elements=(
#CHANGE
)

function create(){
    [[ -z "$element" ]] && element="$1"
    curl --include --request POST "$URL/v1/organizations/#ORG/companies" \
    --user "$USERNAME:$PASSWORD" \
    --header 'Content-Type: application/json' \
    --data-raw '{
        "name": "'"$element"'"
    }'
}


function remove(){
    [[ -z "$element" ]] && element="$1"
    curl  --request DELETE "$URL/v1/organizations/#ORG/companies/$element" \
    --user "$USERNAME:$PASSWORD"
}


function mass(){
    local action
    local element

    action="$1"
    IFS=$'\n'
    for element in "${elements[@]}"; do "$action" "${@:2}"; done
}

"$1" "${@:2}"

EOF
}


function apps_deploy(){
    read -r -d '' deploy <<'EOF'
#!/usr/bin/env bash

export USERNAME=email
export PASSWORD=password

export URL=http://example.com
export PLANET=dev


declare -a elements=(
#CHANGE
)

function create(){
    [[ -z "$element" ]] && element="$1"
    curl --include --request POST "$URL/v1/organizations/#ORG/companies" \
    --user "$USERNAME:$PASSWORD" \
    --header 'Content-Type: application/json' \
    --data-raw '{
        "name": "'"$element"'"
    }'
}


function remove(){
    [[ -z "$element" ]] && element="$1"
    curl  --request DELETE "$URL/v1/organizations/#ORG/companies/$element" \
    --user "$USERNAME:$PASSWORD"
}


function mass(){
    local action
    local element

    action="$1"
    IFS=$'\n'
    for element in "${elements[@]}"; do "$action" "${@:2}"; done
}

"$1" "${@:2}"

EOF
}


function createDeploy(){
    local upload_dir
    local file_shell

    upload_dir="$ROOT_DIR/uploads/$CONTEXT/$ORG"
    file_shell="$upload_dir/${ORG}_${CONTEXT}.sh"
    mkdir -p "$upload_dir"
    list=$(jq .[] "backup/$DATE/$ORG/_LIST.json" | sed 's/"//g')
    echo "$list" >"$upload_dir/${ORG}_${CONTEXT}.txt"
    printf "$list" >"$TEMPO"
    [[ -n "$(LC_ALL=C type -t "${CONTEXT}_deploy")" && "$(LC_ALL=C type -t "${CONTEXT}_deploy")" = function ]] && "${CONTEXT}_deploy"
    echo "$deploy" | sed $'/#CHANGE/{e cat $TEMPO\n}' >"$file_shell"
    sed -i 's/#CHANGE//' "$file_shell"
    sed -i 's/#ORG/'"$ORG"'/' "$file_shell"
}