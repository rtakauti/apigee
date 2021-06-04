#!/usr/bin/env bash

function clone() {
  if [[ ! -d "$ROOT_DIR/git" ]]; then
    git clone "$REPO" "$ROOT_DIR/git"
    git config --global core.autolf true
    git config --global core.safelf true
    checkoutAll
  fi
}

function checkoutAll() {
  (
    cd "$ROOT_DIR/git" || return
    git branch -r |
      grep -v '\->' |
      grep -v 'master' |
      while read -r remote; do
        git branch --track "${remote#origin/}" "$remote"
      done
    git fetch --all &>/dev/null
    git pull --all &>/dev/null
  )
}

function createBranch() {
  local branch
  local source

  branch=$1
  source='master'
  if [[ "$2" ]]; then
    source="$2"
  fi
  cd "$ROOT_DIR/git" || return
  git checkout "$branch" &>/dev/null
  error=$?
  if [[ "$error" -ne 0 ]]; then
    git checkout -b "$branch" "$source"
    rm -f README.md
  fi
  rm -f README.md
}

function pushAll() {
    git gc --aggressive &>/dev/null
    git push --all origin
    git push -f origin --tags
}

function revision() {
  local context
  local error
  local last
  local revision
  local git_dir
  local regex
  local branch

  context=$1
  regex='^[0-9]{1,6}$'
  createBranch 'backup/ALL'
  createBranch 'backup/REVISION'

  for ORG in "${ORGS[@]}"; do
    if [[ -d "$ROOT_DIR/revisions/$context/$ORG" ]]; then
      (
        cd "$ROOT_DIR/revisions/$context/$ORG" || return
        for element in *; do
          if [[ -d "$element" ]]; then
            (
              git_dir="$ROOT_DIR/git/revisions/$ORG/$context/$element"
              mkdir -p "$git_dir"
              cd "$ROOT_DIR/revisions/$context/$ORG/$element" || return
              for zip in revision_*.zip; do

                branch="revisions/$ORG/$context/$element"
                last=$(git show-branch --no-name "$branch" | sed 's/[^0-9]*//g')
                revision=$(echo "$zip" | sed 's/[^0-9]*//g')

                if ! [[ "$last" =~ $regex ]]; then
                  last='000000'
                fi

                if [[ "$last" < "$revision" ]]; then
                  (
                    createBranch "$branch"
                    cd "$ROOT_DIR/git" || return
                    7z x "$ROOT_DIR/revisions/$context/$ORG/$element/$zip" -aoa -o"$git_dir" >/dev/null
                    git add . &>/dev/null
                    git commit -m "$element rev_$revision" &>/dev/null
                    rm -rf ./*
                    wait
                  )
                fi
              done
              cd "$ROOT_DIR/git" || return
              git push origin "$branch" &>/dev/null
              git checkout 'backup/REVISION'
              git merge "$branch" &>/dev/null
            )
          fi
        done
      )
    fi
  done
  (
    cd "$ROOT_DIR/git" || return
    git checkout 'backup/ALL'
    git merge 'backup/REVISION' &>/dev/null
    git tag -f "revision_$DATE" &>/dev/null
    git push -f origin --tags &>/dev/null
    git push origin "backup/REVISION" &>/dev/null
    git push origin "backup/ALL" &>/dev/null
  )
}

function revisionZip() {
  local context
  local git_dir
  local branch

  context=$1
  createBranch 'backup/ALL'
  createBranch 'backup/ZIP'

  for ORG in "${ORGS[@]}"; do
    if [[ -d "$ROOT_DIR/revisions/$context/$ORG" ]]; then
      (
        cd "$ROOT_DIR/revisions/$context/$ORG" || return
        for element in *; do
          if [[ -d "$element" ]]; then
            (
              git_dir="$ROOT_DIR/git/zip/$ORG/$context"
              mkdir -p "$git_dir"
              cp -rf "$ROOT_DIR/revisions/$context/$ORG/$element" "$git_dir"
              branch="zip/$ORG/$context/$element"
              createBranch "$branch"
              git add . &>/dev/null
              git commit -m "$element $DATE" &>/dev/null
              git push origin "$branch" &>/dev/null &
              git checkout 'backup/ZIP' &>/dev/null
              git merge "$branch" &>/dev/null
              rm -rf ./*
              wait
            )
          fi
        done
      )
    fi
  done
  (
    cd "$ROOT_DIR/git" || return
    git checkout 'backup/ALL' &>/dev/null
    git merge 'backup/ZIP' &>/dev/null
    git gc --aggressive &>/dev/null
    git tag -f "zip_$DATE" &>/dev/null
    git push -f origin --tags &>/dev/null
    git push origin 'backup/ZIP' &>/dev/null
    git push origin 'backup/ALL' &>/dev/null
  )
}

function json() {
  local context
  local git_element
  local backup_element
  local branch
  local text
  local files
  local DATE

  context=$1
  createBranch 'backup/ALL'
  createBranch 'backup/JSON'

  cd "$ROOT_DIR/$context/backup" || return
  DATE=$(ls -t *.zip | head -1)
  if [[ -f 'list.txt' ]]; then
    DATE=$(tail -n 1 'list.txt')
  fi
  7z x "${context^^}_$DATE.zip" -aoa -o"$DATE" >/dev/null
  mkdir -p "$ROOT_DIR/git/json"

  for ORG in "${ORGS[@]}"; do

    source "$ROOT_DIR/environments.sh"
    for ENV in "${ENVS[@]}"; do

      if [[ -f "$ROOT_DIR/$context/backup/$DATE/${context}_list.json" ]]; then
        branch="json/$context"
        git_element="$ROOT_DIR/git/json/$context"
        backup_element="$ROOT_DIR/$context/backup/$DATE"
        files=$(jq '.[]' "$ROOT_DIR/$context/backup/$DATE/${context}_list.json" | sed 's/\"//g')
        if [[ "$context" == 'users' ]]; then
          files=$(jq '.user[].name' "$ROOT_DIR/$context/backup/$DATE/${context}_list.json" | sed 's/\"//g')
        fi
        IFS=$'\n'
      elif [[ -f "$ROOT_DIR/$context/backup/$DATE/$ORG/${context}_list.json" ]]; then
        branch="json/$ORG/$context"
        git_element="$ROOT_DIR/git/json/$ORG/$context"
        backup_element="$ROOT_DIR/$context/backup/$DATE/$ORG"
        files=$(jq '.[]' "$ROOT_DIR/$context/backup/$DATE/$ORG/${context}_list.json" | sed 's/\"//g')
        if [[ "$context" == 'apps' ]]; then
          files=$(jq '.app[].name' "$ROOT_DIR/$context/backup/$DATE/$ORG/${context}_jq.json" | sed 's/\"//g')
        fi
        IFS=$'\n'
      elif [[ -f "$ROOT_DIR/$context/backup/$DATE/$ORG/$ENV/${context}_list.json" ]]; then
        branch="json/$ORG/$ENV/$context"
        git_element="$ROOT_DIR/git/json/$ORG/$ENV/$context"
        backup_element="$ROOT_DIR/$context/backup/$DATE/$ORG/$ENV"
        files=$(jq '.[]' "$ROOT_DIR/$context/backup/$DATE/$ORG/$ENV/${context}_list.json" | sed 's/\"//g')
        IFS=$'\n'
      fi

      if [[ -n "$files" ]]; then
        mkdir -p "$git_element"
        createBranch "$branch"
        for file in $files; do
          cp "$backup_element/$file".json "$git_element"
        done
        (
          cd "$ROOT_DIR/git" || return
          git add . &>/dev/null
          git commit -m "$context  $DATE" &>/dev/null
          git push origin "$branch" &>/dev/null
          git checkout 'backup/JSON' &>/dev/null
          git merge "$branch" &>/dev/null
        )
      fi

    done
  done
  (
    git checkout 'backup/ALL' &>/dev/null
    git merge 'backup/JSON' &>/dev/null
    git gc --aggressive &>/dev/null
    git tag -f "json_$DATE" &>/dev/null
    git push -f origin --tags &>/dev/null
    git push origin 'backup/JSON' &>/dev/null
    git push origin 'backup/ALL' &>/dev/null
  )
  rm -rf "$ROOT_DIR/$context/backup/$DATE"
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
