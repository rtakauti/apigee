#!/usr/bin/env bash

function checkoutAll() {
  (
    cd "$ROOT_DIR/git" || return
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
  if [[ ! -d "$ROOT_DIR/git" ]]; then
    git clone "$REPO" "$ROOT_DIR/git"
    git config --global core.autolf true
    git config --global core.safelf true
    (
        cd "$ROOT_DIR/git" || exit
        touch "README.md"
        git add .
        git commit -m "Initial commit"
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
  cd "$ROOT_DIR/git" || return
  git checkout "$branch" &>/dev/null
  error=$?
  [[ "$error" -ne 0 ]] && git checkout -b "$branch" "$source"
  [[ "$source" == master ]] && rm -rf ./*
}

function pushAll() {
  cd "$ROOT_DIR/git" || return
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
  createBranch 'backup/ALL'
  createBranch 'backup/REVISION'
  extractContextBackup
  cd "$ROOT_DIR/git" || return

  for org in "${ORGS[@]}"; do
    backup_dir="$ROOT_DIR/$context/backup/$PERIOD/$org"
    revision_dir="$ROOT_DIR/revisions/$context/$org"
    if [[ ! -d "$revision_dir" ]]; then
      echo "$context/$org" folder does not exist
      continue
    fi
    for element in $(jq '.[]' "$backup_dir/_LIST".json | sed 's/\"//g'); do
      if [[ ! -d "$revision_dir/$element" ]] || [[ "$element" != *"$object"* ]]; then
        echo "$element" folder does not exist
        continue
      fi
      branch="revisions/$org/$context/$element"
      git_dir="$ROOT_DIR/git/$branch"
      for revision in $(jq '.revision[]' "$backup_dir/$element/$element".json | sed 's/\"//g'); do
        cd "$ROOT_DIR/git" || return
        last=$(git show-branch --no-name "$branch" | sed 's/[^0-9]*//g')
        rev=$(printf "%06d" "$revision")
        if ! [[ "$last" =~ $regex ]]; then
          last='000000'
        fi
        if [[ ! -f "$revision_dir/$element/revision_$rev".zip ]]; then
          echo "revision_$rev".zip file does not exist
          continue
        fi
        if [[ "$last" < "$rev" ]]; then
          createBranch "$branch"
          7z x "$revision_dir/$element/revision_$rev".zip -aoa -o"$git_dir" >/dev/null
#          policy_dir="$backup_dir/$element/policies"
#          if [[ -d "$policy_dir/revision_$rev" ]] && [[ -n "$(ls -A "$policy_dir/revision_$rev")" ]]; then
#            mkdir -p "$git_dir/policies"
#            cp "$policy_dir/revision_$rev/"*.json "$git_dir/policies/"
#          fi
          git add . &>/dev/null
          git commit -m "$element rev_$rev" &>/dev/null
          rm -rf ./*
        fi
      done
      cd "$ROOT_DIR/git" || return
      [[ $(git status) != *'nothing to commit, working tree clean'* ]] && git checkout -- .
      git checkout 'backup/REVISION'
      git rebase "$branch" &>/dev/null
    done
  done
  cd "$ROOT_DIR/git" || return
  git checkout 'backup/ALL'
  git rebase 'backup/REVISION' &>/dev/null
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
  cd "$ROOT_DIR/git" || return

  for org in "${ORGS[@]}"; do
    backup_dir="$ROOT_DIR/$context/backup/$PERIOD/$org"
    revision_dir="$ROOT_DIR/revisions/$context/$org"
    if [[ ! -d "$revision_dir" ]]; then
      echo "$context/$org" folder does not exist
      continue
    fi

    for element in $(jq '.[]' "$backup_dir/_LIST".json | sed 's/\"//g'); do
      if [[ ! -d "$revision_dir/$element" ]] || [[ "$element" != *"$object"* ]]; then
        echo "$element" folder does not exist
        continue
      fi
      branch="zip/$org/$context/$element"
      git_dir="$ROOT_DIR/git/$branch"
      createBranch "$branch"
      mkdir -p "$git_dir"
      cp "$revision_dir/$element/"*.zip "$git_dir"
      [[ ! -f "$git_dir/revisions.csv" ]] && echo 'Revision,Hash' >"$git_dir/revisions.csv"
      jq '.[]' "$backup_dir/$element/revisions.json" |
        sed 's/\"//g' | sed 's/|/\,/g' >>"$git_dir/revisions.csv"
      git add . &>/dev/null
      git commit -m "$element $PERIOD" &>/dev/null
      git checkout 'backup/ZIP'
      git merge "$branch" &>/dev/null
      rm -rf ./*
    done
  done
  cd "$ROOT_DIR/git" || return
  [[ $(git status) != *'nothing to commit, working tree clean'* ]] && git checkout -- .
  git checkout 'backup/ALL'
  git merge 'backup/ZIP' &>/dev/null
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

  context=$1
  createBranch 'backup/ALL'
  createBranch 'backup/JSON'
  extractContextBackup
  cd "$ROOT_DIR/git" || return

  function createCommit() {
    local message

    message=$context
    [[ -n "$element" ]] && message=$element
    git_dir="$ROOT_DIR/git/$branch"
    createBranch "$branch"
    mkdir -p "$git_dir"
    cp "$backup_dir"/*.json "$git_dir"
    git add . &>/dev/null
    git commit -m "$message $PERIOD" &>/dev/null
    rm -rf ./*
    git checkout 'backup/JSON' &>/dev/null
    git merge "$branch" &>/dev/null
  }

  if [[ -f "$ROOT_DIR/$context/backup/$PERIOD"/_LIST.json ]]; then
    branch="json/$context"
    createCommit
  else
    for ORG in "${ORGS[@]}"; do
      if [[ -f "$ROOT_DIR/$context/backup/$PERIOD/$ORG"/_LIST.json ]]; then
        branch="json/$ORG/$context"
        backup_dir="$ROOT_DIR/$context/backup/$PERIOD/$ORG"
        if [[ "$context" == 'apis' ]] || [[ "$context" == 'sharedflows' ]]; then
          for element in $(jq '.[]' "$backup_dir/_LIST".json | sed 's/\"//g'); do
            branch="json/$ORG/$context/$element"
            backup_dir="$ROOT_DIR/$context/backup/$PERIOD/$ORG/$element"
            createCommit
          done
        else
          createCommit
        fi
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
  cd "$ROOT_DIR/git" || return
  [[ $(git status) != *'nothing to commit, working tree clean'* ]] && git checkout -- .
  git checkout 'backup/ALL' &>/dev/null
  git merge 'backup/JSON' &>/dev/null
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
  mkdir -p "$ROOT_DIR/git/ssh"

  for ORG in "${ORGS[@]}"; do

    source "$ROOT_DIR/environments.sh"
    for ENV in "${ENVS[@]}"; do

      if [[ -f "$ROOT_DIR/$context/backup/$DATE/${context}.txt" ]]; then
        cp "$ROOT_DIR/$context/backup/$DATE/${context}.txt" "$ROOT_DIR/git/ssh/context.txt"
        text='--insecure "$URL/v1/context" \'
      elif [[ -f "$ROOT_DIR/$context/backup/$DATE/$ORG/${context}.txt" ]]; then
        cp "$ROOT_DIR/$context/backup/$DATE/$ORG/${context}.txt" "$ROOT_DIR/git/ssh/context.txt"
        text='--insecure "$URL/v1/organizations/ORGANIZACAO/context" \'
        org="_$ORG"
      elif [[ -f "$ROOT_DIR/$context/backup/$DATE/$ORG/$ENV/${context}.txt" ]]; then
        cp "$ROOT_DIR/$context/backup/$DATE/$ORG/$ENV/${context}.txt" "$ROOT_DIR/git/ssh/context.txt"
        text='--insecure "$URL/v1/organizations/ORGANIZACAO/environments/AMBIENTE/context" \'
        env="_$ENV"
      fi

      if [[ -f "$ROOT_DIR/git/ssh/context.txt" ]] && [[ "$text" ]]; then
        createBranch 'ssh/files' 'backup/SSH'
        cd "$ROOT_DIR/git" || return
        content=$(echo "$texts" | sed $'/TROCAR/{e cat ssh/context.txt\n}' | sed ':a;N;$!ba;s/TROCAR\n//g')
        content1="${content//MUDAR/$text}"
        content="${content1//AMBIENTE/$ENV}"
        content1="${content//ORGANIZACAO/$ORG}"
        content="${content1//ENDERECO/$URL}"
        echo "${content//context/$context}" >"$ROOT_DIR/git/ssh/create_$context$org$env.sh"
        rm "$ROOT_DIR/git/ssh/context.txt"
        unset text
        git add . &>/dev/null
        git commit -m "Recover $context $DATE" &>/dev/null
        git checkout 'backup/ALL' &>/dev/null
        git merge 'ssh/files' &>/dev/null
        git checkout 'backup/SSH' &>/dev/null
        git merge 'ssh/files' &>/dev/null
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

  cd "$ROOT_DIR/git/ssh" || return

  echo "$file" >"$ROOT_DIR/git/ssh/all.sh"
  for file in *.sh; do
    if [[ "$file" != 'all.sh' ]]; then
      echo "bash $file" >>"$ROOT_DIR/git/ssh/all.sh"
    fi
  done

  git add . &>/dev/null
  git commit -m "RECOVER $DATE" &>/dev/null
  git checkout 'backup/ALL' &>/dev/null
  git merge 'backup/SSH' &>/dev/null
  git gc --aggressive &>/dev/null
  git tag -f "ssh_$DATE" &>/dev/null
  git push -f origin --tags &>/dev/null
  git push origin 'backup/SSH' &>/dev/null
  git push origin 'backup/ALL' &>/dev/null
  rm -rf "$ROOT_DIR/$context/backup/$DATE"
}

function gitRevision() {
  revision 'sharedflows'
  revisionZip 'sharedflows'
  revision 'apis'
  revisionZip 'apis'
}
