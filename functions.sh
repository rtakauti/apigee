#!/usr/bin/env bash

source "$ROOT_DIR/functions/basic.sh"

function makeDir() {
  discover
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
  fi

  if [[ -n $ENV ]]; then
    ACTIVITY_DIR="$ACTIVITY_DIR/$ENV"
    SUFFIX="${SUFFIX}_$ENV"
  fi

  if [[ "$CONTEXT" == 'organizations' ]] || [[ "$CONTEXT" == 'users' ]]; then
    SUFFIX="$CONTEXT"
  fi

  mkdir -p "$ACTIVITY_DIR"
  FILENAME="$ACTIVITY_DIR/$CONTEXT"

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

  header
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
}

function compress() {
  discover
  mkdir -p "$ROOT_DIR/$ACTIVITY/$DATE/$ORG"
  (
    cd "$ACTIVITY" || exit
    if [[ "$CONTEXT" == 'apigee' ]]; then
      7z a -r "${CONTEXT^^}_$DATE".zip "$DATE" >/dev/null
      rm -rf "$DATE"
    else
      7z a -r "${CONTEXT^^}_$DATE".zip "./$DATE/$ORG/*.*" >/dev/null
      mv "${CONTEXT^^}_$DATE.zip" "$ROOT_DIR/$ACTIVITY/$DATE/$ORG/${CONTEXT^^}_$DATE.zip"
    fi
  )

  if [[ "$MASS" != true ]]; then
    (
      cd "$ROOT_DIR/$ACTIVITY" || exit
      7z a -r "APIGEE_$DATE".zip "$DATE" >/dev/null
      rm -rf "$DATE"
    )
  fi

  if [[ "$ACTIVITY" == 'backup' ]]; then
    (
      cd "$RECOVER" || exit
      7z a -r "RECOVER_$DATE".zip "./$DATE/*.txt" >/dev/null
      rm -rf "$DATE"
    )
  fi
}

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

function makeBackupList() {
  local file
  local jq_query
  local environments

  VERB='GET'
  URI="$1"
  type="$2"
  jq_query="$3"
  file="${FILENAME}_${type}.json"

  if [[ -z "$type" ]]; then
    file="$FILENAME.json"
  fi

  makeCurl
  status "$CURL_RESULT backup done see $file"
  payload=$(jq <"$TEMP")
  echo "$payload" >"$file"

  if [[ -z "$payload" ]]; then
    echo 'no items found' | tee -a "$LOG"
    return
  fi

  if [[ "$type" == 'list' ]]; then
    LIST=$(echo "$payload" | jq '.[]' | sed 's/\"//g')
    echo "$payload" | jq 'map(.+"|not_delete") | .[]' | sed 's/\"//g' >"$REMOVE/$SUFFIX.txt"

    if [[ "$CONTEXT" == 'organizations' ]]; then
      printf "export ORGS=(%s)\n" "$(echo "$payload" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g')" >"$ROOT_DIR/organizations.sh"
    fi

    if [[ "$CONTEXT" == 'environments' ]]; then
      read -r -d '' environments <<'EOF'
#!/usr/bin/env bash

#source ./organizations.sh

#TROCAR

export ENVS

EOF
      if [[ -f "$ROOT_DIR/environments.sh" ]]; then
        environments=$(cat "$ROOT_DIR/environments.sh")
      fi
      printf 'if [[ "$ORG" == '%s' ]]; then' "$ORG" >"$TEMP"
      printf "\nENVS=(%s)\n" "$(echo "$payload" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g')" >>"$TEMP"
      printf "fi\n" >>"$TEMP"
      echo "$environments" | sed $'/#TROCAR/{e cat $TEMP\n}' >"$ROOT_DIR/environments.sh"
    fi

    if [[ "$CONTEXT" == 'users' ]]; then
      LIST=$(echo "$payload" | jq '.user[].name' | sed 's/\"//g')
    fi
  fi

  if [[ "$type" == 'jq' ]]; then
    LIST=$(echo "$payload" | jq "$jq_query" | sed 's/\"//g')
  fi
}

function makeBackupSub() {
  local sub_file
  local sub_uri
  local object
  local object_uri
  local payload
  local revision_dir
  local name
  local revision_max
  local revisions
  local rev
  local jq_query

  if [[ -z "$LIST" ]]; then
    return
  fi

  URI="$1"
  ACTION="$2"
  name='name'

  if [[ -n "$3" ]]; then
    sub_uri="/$3"
  fi

  if [[ "$CONTEXT" == 'developers' ]] || [[ "$CONTEXT" == 'users' ]]; then
    name='email'
  fi

  for object in $LIST; do
    sub_file="$ACTIVITY_DIR/$object.json"

    if [[ "$type" == 'jq' ]]; then
      IFS='|' read -ra object <<<"$object"
      sub_file="$ACTIVITY_DIR/${object[1]}.json"
    fi

    object_uri="${object// /%20}"
    makeCurlObject "$sub_uri"
    status "$CURL_RESULT backup done see $sub_file"
    jq_query='.'
    if [[ "$CONTEXT" == 'apps' ]]; then
      jq_query='.credentials[].consumerKey = "*******" | .credentials[].consumerSecret = "*******"'
    fi
    payload=$(cat "$TEMP" | jq "$jq_query")
    echo "$payload" >"$sub_file"

    if [[ "$ACTION" == 'revision' ]]; then
      revisions=$(echo "$payload" | jq '.revision[]' | sed 's/\"//g')
      IFS=$'\n'
      revision_max=$(echo "${revisions[*]}" | sort -nr | head -n1)
      for revision in $revisions; do
        revision_dir="$ROOT_DIR/revisions/$CONTEXT/$ORG/$object"
        mkdir -p "$revision_dir"
        rev=$(printf "%04d" "$revision")
        (
          cd "$revision_dir" || exit
          if [[ ! -f "$revision_dir/revision_${rev}.zip" ]]; then
            makeCurlObject "/revisions/${revision}?format=bundle"
            cp "$TEMP" "$revision_dir/revision_${rev}.zip"
          fi
        )
        if [[ ! -d "$ROOT_DIR/uploads/$CONTEXT/$ORG" ]]; then
          mkdir -p "$ROOT_DIR/uploads/$CONTEXT/$ORG"
        fi

        if [[ $revision == "$revision_max" ]]; then
          cp "$TEMP" "$ROOT_DIR/uploads/$CONTEXT/$ORG/${object}_rev${revision}_$(TZ=GMT date +"%Y_%m_%d").zip"
        fi
        status "$CURL_RESULT revision done see revision/$object"
      done
    fi

    payload=$(echo "$payload" | jq -c '. |  del(.createdAt,.createdBy,.lastModifiedAt,.lastModifiedBy,.organization,.apps,.metaData,.revision)')
    echo "$payload" >>"$FILENAME.txt"

    if [[ "$ACTION" == 'status' ]]; then
      paste -d "|" <(echo "$payload" | jq --arg name "$name" '.[$name]' | sed 's/\"//g') <(echo "$payload" | jq '.status' | sed 's/\"//g') >>"${FILENAME}_status.txt"
    fi

    paste -d "|" <(echo "$payload" | jq --arg name "$name" '.[$name]' | sed 's/\"//g') <(echo "$payload" | jq -c 'del(.name,.status)') >>"${FILENAME}_change.txt"

  done

  cp "$FILENAME.txt" "$RECOVER/$SUFFIX.txt"
  cp "$FILENAME.txt" "$RECOVER_DIR/$SUFFIX.txt"

  if [[ "$ACTION" == 'status' ]]; then
    mv "${FILENAME}_status.txt" "$ROOT_DIR/change/${SUFFIX}_status.txt"
  fi

  if [[ "$CONTEXT" != 'apis' ]] && [[ "$CONTEXT" != 'sharedflows' ]]; then
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

function mass() {
  activity 'organizations'
  activity 'users'
  activity 'environments'
  activity 'companies'
  activity 'targetservers'
  activity 'apps'
  activity 'apiproducts'
  activity 'developers'
  activity 'apis'
  activity 'sharedflows'
  activity 'virtualhosts'
  activity 'keyvaluemaps'
  activity 'userroles'
  activity 'caches'
  activity 'keystores'
  activity 'references'
  activity 'reports'
}

function activity() {
  local context

  context="$1"
  if [[ "$ACTIVITY" == 'clean' ]]; then
    clean "$context"
  elif [[ "$ACTIVITY" == 'linux' ]]; then
    linux "$context"
  else
    execute "$context"
  fi
}

function execute() {
  local context

  context="$1"
  (
    cd "$context" || exit
    if [[ -f "${ACTIVITY}_${context}".sh ]]; then
      bash "${ACTIVITY}_${context}".sh &
      wait
    fi
  )
}

function clean() {
  local context
  local activity
  declare -a activities=("backup" "create" "update" "delete")

  context="$1"
  for activity in "${activities[@]}"; do
    if [[ -d "$context/$activity" ]]; then
      (
        cd "$context/$activity" || exit
        rm -rf ./*
        rm -f ./*.*
      )
    fi
  done
}

function linux() {
  local context

  context="$1"
  (
    cd "$context" || exit
    dos2unix ./*.*
    chmod +x ./*.sh
  )
}

function clone() {
  if [[ ! -d "$ROOT_DIR/git" ]]; then
    git clone "$REPO" git
    git config --global core.autocrlf true
    git config --global core.safecrlf false
  fi
}

function create_branch() {
  local branch
  local source

  branch=$1
  source='master'
  if [[ "$2" ]]; then
    source="$2"
  fi
  cd "$ROOT_DIR/git" || exit
  git checkout "$branch" &>/dev/null
  error=$?
  if [[ "$error" -ne 0 ]]; then
    git checkout -b "$branch" "$source"
    rm -f README.md
  fi
  rm -f README.md
}

function revision() {
  local context
  local error
  local last

  context=$1
  create_branch 'backup/ALL'
  create_branch 'backup/REVISION'
  cd "$ROOT_DIR/revisions/$context" || exit
  for folder in *; do
    if [[ -d "$folder" ]]; then
      (
        mkdir -p "$ROOT_DIR/git/$context/$folder"
        cd "$ROOT_DIR/revisions/$context/$folder" || exit
        for zip in revision_*.zip; do
          create_branch "revision/$context/$folder"
          last=$(git show-branch --no-name "revision/$context/$folder")
          if [[ "$last" != "revision_"* ]]; then
            last="revision_0000.zip"
          fi
          if [[ "$last" < "$zip" ]]; then
            (
              7z x "$ROOT_DIR/revisions/$context/$folder/$zip" -aoa -o"$ROOT_DIR/git/$context/$folder" >/dev/null
              git add . &>/dev/null
              git commit -m "$zip" &>/dev/null
              git push origin "revision/$context/$folder" &>/dev/null &
              rm -rf ./*
              wait
            )
          fi
        done
        cd "$ROOT_DIR/git" || exit
        git checkout 'backup/REVISION' &>/dev/null
        git rebase "revision/$context/$folder" &>/dev/null
        git checkout 'backup/ALL' &>/dev/null
        git rebase "revision/$context/$folder" &>/dev/null
      )
    fi
  done
  (
    cd "$ROOT_DIR/git" || exit
    git gc --aggressive &>/dev/null
    git push -f origin "backup/REVISION" &>/dev/null &
    git push -f origin "backup/ALL" &>/dev/null &
    wait
  )
}

function revision_zip() {
  local context

  context=$1
  create_branch 'backup/ALL'
  create_branch 'backup/ZIP'
  cd "$ROOT_DIR/revisions/$context" || exit
  for folder in *; do
    if [[ -d "$folder" ]]; then
      (
        mkdir -p "$ROOT_DIR/git/zip/$context"
        cp -rf "$ROOT_DIR/revisions/$context/$folder" "$ROOT_DIR/git/zip/$context"
        create_branch "zip/$context/$folder"
        git add . &>/dev/null
        git commit -m "$folder  $DATE" &>/dev/null
        git push origin "zip/$context/$folder" &>/dev/null &
        git checkout 'backup/ZIP' &>/dev/null
        git rebase "zip/$context/$folder" &>/dev/null
        git checkout 'backup/ALL' &>/dev/null
        git rebase 'backup/ZIP' &>/dev/null
        rm -rf ./*
        wait
      )
    fi
  done
  (
    cd "$ROOT_DIR/git" || exit
    git gc --aggressive &>/dev/null
    git push -f origin 'backup/ZIP' &>/dev/null &
    git push -f origin 'backup/ALL' &>/dev/null &
    wait
  )
}

function backup_json() {
  local object
  local name

  create_branch "$branch"
  mkdir -p "$git_folder"
  jq_query='.name'
  if [[ "$context" == 'users' ]]; then
    jq_query='.emailId'
  fi
  while IFS= read -r element; do
    object=$(echo "$element" | jq -e '.')
    name=$(echo "$object" | jq -e "$jq_query" | sed 's/\"//g')
    echo "$object" >"$git_folder/$name.json"
  done <"$text"
  (
    cd "$ROOT_DIR/git" || exit
    git add . &>/dev/null
    git commit -m "$context  $DATE" &>/dev/null
    git push origin "$branch" &>/dev/null &
    git checkout 'backup/JSON' &>/dev/null
    git rebase "$branch" &>/dev/null
    git checkout 'backup/ALL' &>/dev/null
    git rebase 'backup/JSON' &>/dev/null
    git push -f origin 'backup/JSON' &>/dev/null &
    git push -f origin 'backup/ALL' &>/dev/null &
    rm -rf ./*
    wait
  )
}

function json() {
  local context
  local git_folder
  local branch
  local text

  context=$1
  create_branch 'backup/ALL'
  create_branch 'backup/JSON'
  branch="json/$context"
  git_folder="$ROOT_DIR/git/json/$context"
  if [[ -f "$ROOT_DIR/recover/${context}_.txt" ]]; then
    text="$ROOT_DIR/recover/${context}_.txt"
    backup_json
    return
  fi
  for ORG in ${ORGS[*]}; do
    if [[ -f "$ROOT_DIR/recover/${context}_${ORG}.txt" ]]; then
      text="$ROOT_DIR/recover/${context}_${ORG}.txt"
      backup_json
    fi
    for ENV in ${ENVS[*]}; do
      if [[ -f "$ROOT_DIR/recover/${context}_${ORG}_${ENV}.txt" ]]; then
        branch="json/$ENV/$context"
        git_folder="$ROOT_DIR/git/json/$ENV/$context"
        text="$ROOT_DIR/recover/${context}_${ORG}_${ENV}.txt"
        backup_json
      fi
    done
  done
}

function ssh_backup() {
  local content
  local content1

  (
    cd "$ROOT_DIR/git" || exit
    create_branch 'ssh/files' 'backup/SSH'
    content=$(echo "$texts" | sed $'/TROCAR/{e cat ssh/context.txt\n}' | sed ':a;N;$!ba;s/TROCAR\n//g')
    content1="${content//MUDAR/$text}"
    content="${content1//AMBIENTE/$ENV}"
    content1="${content//ORGANIZACAO/$ORG}"
    content="${content1//ENDERECO/$APIGEE}"
    echo "${content//context/$context}" >"$ROOT_DIR/git/ssh/create_$context$env.sh"
    rm "$ROOT_DIR/git/ssh/context.txt"
    git add . &>/dev/null
    git commit -m "$context  $DATE" &>/dev/null
    git checkout 'backup/SSH' &>/dev/null
    git rebase 'ssh/files' &>/dev/null
    git branch -D 'ssh/files' &>/dev/null
  )
}

function ssh_create() {
  local context
  local texts
  local text
  local env

  context=$1
  read -r -d '' texts <<'EOF'
#!/usr/bin/env bash

elements=($(echo '
TROCAR
'))

TEMP=$(mktemp)
export TEMP
export APIGEE=ENDERECO
#    export USERNAME=**************
#    export PASSWORD=**************
export LOG=log_context.txt

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

function sendRequest() {
  local data

  data="$1"
  CURL_RESULT=$(
    curl --location --request POST \
      MUDAR
      --output "$TEMP" \
      --user "$USERNAME:$PASSWORD" \
      --header 'Content-Type: application/json' \
      --silent \
      --write-out "%{http_code}" \
      --data "$data"
  )
}

for element in "${elements[@]}"; do
  sendRequest "$element"
  status "$CURL_RESULT creation done"
  cat "$TEMP" >> output.txt
done
cat output.txt | jq -s '.' > output_context.json
rm output.txt
EOF
  create_branch 'backup/ALL'
  create_branch 'backup/SSH'
  if [[ ! -d "$ROOT_DIR/git/ssh" ]]; then
    mkdir -p "$ROOT_DIR/git/ssh"
  fi
  if [[ -f "$ROOT_DIR/recover/${context}_.txt" ]]; then
    cp "$ROOT_DIR/recover/${context}_.txt" "$ROOT_DIR/git/ssh/context.txt"
    text='--insecure "$APIGEE/v1/context" \'
    ssh_backup
  else
    for ORG in ${ORGS[*]}; do
      if [[ -f "$ROOT_DIR/recover/${context}_${ORG}.txt" ]]; then
        cp "$ROOT_DIR/recover/${context}_${ORG}.txt" "$ROOT_DIR/git/ssh/context.txt"
        text='--insecure "$APIGEE/v1/organizations/ORGANIZACAO/context" \'
        ssh_backup
      else
        for ENV in ${ENVS[*]}; do
          if [[ -f "$ROOT_DIR/recover/${context}_${ORG}_${ENV}.txt" ]]; then
            cp "$ROOT_DIR/recover/${context}_${ORG}_${ENV}.txt" "$ROOT_DIR/git/ssh/context.txt"
            text='--insecure "$APIGEE/v1/organizations/ORGANIZACAO/environments/AMBIENTE/context" \'
            env="_$ENV"
            ssh_backup
          fi
        done
      fi
    done
  fi
  cd "$ROOT_DIR/git/ssh" || exit
  read -r -d '' file <<'EOF'
#!/usr/bin/env bash

########################
## BASH PARA RECOVER ###
########################


export USERNAME=**************
export PASSWORD=**************

#for file in *.sh; do
#  bash "$file"&
#  wait
#done

## OU PODE ESCOLHER


EOF
  echo "$file" >all.sh
  for file in *.sh; do
    if [[ "$file" != 'all.sh' ]]; then
      echo "bash $file" >>all.sh
    fi
  done
  git add . &>/dev/null
  git commit -m "BASH RECOVER  $DATE" &>/dev/null
  git checkout 'backup/ALL' &>/dev/null
  git rebase 'backup/SSH' &>/dev/null
  git push -f origin 'backup/SSH' &>/dev/null
  git push -f origin 'backup/ALL' &>/dev/null
}
