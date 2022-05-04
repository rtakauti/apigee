#!/usr/bin/env bash

function checkoutAll() {
  (
    cd "$GIT_FOLDER" || exit
    git branch -r |
      grep -v '\->' |
      grep -v 'master' |
      while read -r remote; do
        git branch --track "${remote#origin/}" "$remote" &>/dev/null
      done
    git fetch --all &>/dev/null
    git pull --all &>/dev/null
  )
}

function clone() {
  if [[ ! -d "$GIT_FOLDER" ]]; then
    git clone "$REPO" "$GIT_FOLDER"
    git config --global core.autolf true
    git config --global core.safelf true
    (
        cd "$GIT_FOLDER" || exit
        git commit --allow-empty -m  "Initial rev_000000"
    )
  fi
  checkoutAll
}

function createBranch() {
  local branch
  local source

  branch=$1
  source='master'
  [[ -n "$2" ]] && source="$2"
  cd "$GIT_FOLDER" || return
  git checkout "$branch" &>/dev/null
  error=$?
  [[ "$error" -ne 0 ]] && git checkout -b "$branch" "$source"
}

function pushAll() {
  cd "$GIT_FOLDER" || return
  git gc --aggressive &>/dev/null
  git push --all --force origin
  git push -f origin --tags
}

function revision() {
  local org
  local context
  local object
  local element
  local last
  local revision
  local rev
  local regex
  local branch
  local git_dir
  local backup_dir
  local revision_dir
  local policy_dir

  context=$1
  object=$2
  regex='^[0-9]{1,6}$'
  createBranch 'backup/REVISION'
  createBranch 'backup/ALL'
  extractContextBackup

  for org in "${ORGS[@]}"; do
    backup_dir="$ROOT_DIR/$context/backup/$PERIOD/$org"
    total=$(jq '. | length' "$backup_dir/_LIST.json")
    revision_dir="$ROOT_DIR/revisions/$context/$org"
    [[ ! -d "$revision_dir" ]] && continue
    for element in $(jq '.[]' "$backup_dir/_LIST".json | sed 's/\"//g'); do
      [[ "$element" != *"$object"* ]] || [[ ! -d "$revision_dir/$element" ]] && continue
      branch="revisions/$org/$context/$element"
      git_dir="$GIT_FOLDER/$branch"
      for revision in $(jq '.revision[]' "$backup_dir/$element/$element".json | sed 's/\"//g'); do
        cd "$GIT_FOLDER" || return
        last=$(git show-branch --no-name "$branch" | sed 's/[^0-9]*//g')
        last=${last: -6}
        rev=$(printf "%06d" "$revision")
        ! [[ "$last" =~ $regex ]] && last='000000'
        [ "$last" -ge "$rev" ] || [[ ! -f "$revision_dir/$element/revision_$rev".zip ]] && continue
        createBranch "$branch"
        7z x "$revision_dir/$element/revision_$rev".zip -aoa -o"$git_dir" >/dev/null
        git add . &>/dev/null
        git commit -m "$element rev_$rev" &>/dev/null
        rm -rf ./*
      done
      cd "$GIT_FOLDER" || return
      git checkout 'backup/REVISION'
      git merge --squash "$branch" &>/dev/null
      git add .
      git commit -m "$element $PERIOD"
    done
  done
  cd "$GIT_FOLDER" || return
  git checkout --orphan 'auxiliar' 'backup/REVISION'
  git commit -m "REVISION $PERIOD"
  git checkout 'backup/ALL'
  git rebase 'auxiliar'
  git branch -D 'auxiliar'
  git tag -f "revision_$PERIOD" &>/dev/null
  pushAll
  rm -rf "$ROOT_DIR/$context/backup/$PERIOD"
}

function revisionZip() {
    local org
    local context
    local object
    local element
    local branch
    local git_dir
    local revision_dir

    context=$1
    object=$2
    createBranch 'backup/ALL'
    createBranch 'backup/ZIP'
    extractContextBackup
    for org in "${ORGS[@]}"; do
        backup_dir="$ROOT_DIR/$context/backup/$PERIOD/$org"
        revision_dir="$ROOT_DIR/revisions/$context/$org"
        [[ ! -d "$revision_dir" ]] && continue
        for element in $(jq '.[]' "$backup_dir/_LIST".json | sed 's/\"//g'); do
            [[ "$element" != *"$object"* ]] || [[ ! -d "$revision_dir/$element" ]] && continue
            branch="zip/$org/$context/$element"
            git_dir="$GIT_FOLDER/$branch"
            createBranch "$branch"
            [[ ! -d "$git_dir" ]] && mkdir -p "$git_dir"
            cp "$revision_dir/$element/"*.zip "$git_dir"
            if [[ $(git status) != *'nothing to commit, working tree clean'* ]]; then
                git add . &>/dev/null
                git commit -m "$element $PERIOD" &>/dev/null
            fi
            rm -rf ./*
            git checkout 'backup/ZIP'
            git merge --squash "$branch" &>/dev/null
            git add .
            git commit -m "$element $PERIOD"
        done
    done
    cd "$GIT_FOLDER" || return
    git checkout --orphan 'auxiliar' 'backup/ZIP'
    git commit -m "ZIP $PERIOD"
    git checkout 'backup/ALL'
    git rebase 'auxiliar'
    git branch -D 'auxiliar'
    git tag -f "zip_$PERIOD" &>/dev/null
    pushAll
    rm -rf "$ROOT_DIR/$context/backup/$PERIOD"
}


function json() {
  local ORG
  local ENV
  local context
  local element
  local branch
  local text
  local git_dir
  local backup_dir

  function createCommit() {
    local message

    message="$context"
    [[ -n "$element" ]] && message="$element"
    createBranch "$branch"
    git_dir="$GIT_FOLDER/$branch"
    mkdir -p "$git_dir"
    cp "$backup_dir"/*.json "$git_dir"
    if [[ $(git status) != *'nothing to commit, working tree clean'* ]]; then
        git add . &>/dev/null
        git commit -m "$message $PERIOD" &>/dev/null
    fi
    rm -rf ./*
    git checkout 'backup/JSON' &>/dev/null
    git merge --squash "$branch" &>/dev/null
    git add .
    git commit -m "$CONTEXT $PERIOD"
  }

  context=$1
  createBranch 'backup/ALL'
  createBranch 'backup/JSON'
  extractContextBackup
  if [[ -f "$ROOT_DIR/$context/backup/$PERIOD"/_LIST.json ]]; then
    branch="json/$context"
    createCommit
  else
    for ORG in "${ORGS[@]}"; do
      if [[ -f "$ROOT_DIR/$context/backup/$PERIOD/$ORG"/_LIST.json ]]; then
        branch="json/$ORG/$context"
        backup_dir="$ROOT_DIR/$context/backup/$PERIOD/$ORG"
        for element in $(jq '.[]' "$backup_dir/_LIST".json | sed 's/\"//g'); do
            branch="json/$ORG/$context/$element"
            backup_dir="$ROOT_DIR/$context/backup/$PERIOD/$ORG/$element"
            createCommit
        done
      else
        source "$ROOT_DIR/environments.sh"
        for ENV in "${ENVS[@]}"; do
          if [[ -f "$ROOT_DIR/$context/backup/$PERIOD/$ORG/$ENV"/_LIST.json ]]; then
            branch="json/$ORG/$ENV/$context"
            backup_dir="$ROOT_DIR/$context/backup/$PERIOD/$ORG/$ENV"
            createCommit
          fi
        done
      fi
    done
  fi
  cd "$GIT_FOLDER" || return
  git checkout --orphan 'auxiliar' 'backup/JSON'
  git commit -m "JSON $PERIOD"
  git checkout 'backup/ALL'
  git rebase 'auxiliar'
  git branch -D 'auxiliar'
  git tag -f "json_$PERIOD" &>/dev/null
  pushAll
  rm -rf "$ROOT_DIR/$context/backup/$PERIOD"
}


function createSsh() {
  local context
  local texts
  local text
  local org
  local env
  local content
  local content1
  local DATE

  context=$1
  read -r -d '' texts <<'EOF'
#!/usr/bin/env bash

elements=($(echo '
TROCAR
'))

TEMP=$(mktemp)
export TEMP
export URL=ENDERECO
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

  createBranch 'backup/ALL'
  createBranch 'backup/SSH'

  cd "$ROOT_DIR/$context/backup" || return
  DATE=$(ls -t *.zip | head -1)
  if [[ -f 'list.txt' ]]; then
    DATE=$(tail -n 1 'list.txt')
  fi
  7z x "${context^^}_$DATE.zip" -aoa -o"$DATE" >/dev/null
  mkdir -p "$GIT_FOLDER/ssh"

  for ORG in "${ORGS[@]}"; do

    source "$ROOT_DIR/environments.sh"
    for ENV in "${ENVS[@]}"; do

      if [[ -f "$ROOT_DIR/$context/backup/$DATE/${context}.txt" ]]; then
        cp "$ROOT_DIR/$context/backup/$DATE/${context}.txt" "$GIT_FOLDER/ssh/context.txt"
        text='--insecure "$URL/v1/context" \'
      elif [[ -f "$ROOT_DIR/$context/backup/$DATE/$ORG/${context}.txt" ]]; then
        cp "$ROOT_DIR/$context/backup/$DATE/$ORG/${context}.txt" "$GIT_FOLDER/ssh/context.txt"
        text='--insecure "$URL/v1/organizations/ORGANIZACAO/context" \'
        org="_$ORG"
      elif [[ -f "$ROOT_DIR/$context/backup/$DATE/$ORG/$ENV/${context}.txt" ]]; then
        cp "$ROOT_DIR/$context/backup/$DATE/$ORG/$ENV/${context}.txt" "$GIT_FOLDER/ssh/context.txt"
        text='--insecure "$URL/v1/organizations/ORGANIZACAO/environments/AMBIENTE/context" \'
        env="_$ENV"
      fi

      if [[ -f "$GIT_FOLDER/ssh/context.txt" ]] && [[ "$text" ]]; then
        createBranch 'ssh/files' 'backup/SSH'
        cd "$GIT_FOLDER" || return
        content=$(echo "$texts" | sed $'/TROCAR/{e cat ssh/context.txt\n}' | sed ':a;N;$!ba;s/TROCAR\n//g')
        content1="${content//MUDAR/$text}"
        content="${content1//AMBIENTE/$ENV}"
        content1="${content//ORGANIZACAO/$ORG}"
        content="${content1//ENDERECO/$URL}"
        echo "${content//context/$context}" >"$GIT_FOLDER/ssh/create_$context$org$env.sh"
        rm "$GIT_FOLDER/ssh/context.txt"
        unset text
        git add . &>/dev/null
        git commit -m "Recover $context $DATE" &>/dev/null
        git checkout 'backup/ALL' &>/dev/null
        git rebase 'ssh/files' &>/dev/null
        git checkout 'backup/SSH' &>/dev/null
        git rebase 'ssh/files' &>/dev/null
        git branch -D 'ssh/files' &>/dev/null
      fi
    done
  done

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

  cd "$GIT_FOLDER/ssh" || return

  echo "$file" >"$GIT_FOLDER/ssh/all.sh"
  for file in *.sh; do
    if [[ "$file" != 'all.sh' ]]; then
      echo "bash $file" >>"$GIT_FOLDER/ssh/all.sh"
    fi
  done

  git add . &>/dev/null
  git commit -m "RECOVER $DATE" &>/dev/null
  git checkout 'backup/ALL' &>/dev/null
  git rebase 'backup/SSH' &>/dev/null
  git gc --aggressive &>/dev/null
  git tag -f "ssh_$DATE" &>/dev/null
  git push -f origin --tags &>/dev/null
  git push origin 'backup/SSH' &>/dev/null
  git push origin 'backup/ALL' &>/dev/null
  rm -rf "$ROOT_DIR/$context/backup/$DATE"
}
