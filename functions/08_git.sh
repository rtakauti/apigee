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
  if [[ -f "$ROOT_DIR/$context/backup/$PERIOD"/_LIST.json ]]; then
    branch="json/$context"
    createCommit
  else
    for ORG in "${ORGS[@]}"; do
      if [[ -f "$ROOT_DIR/$context/backup/$PERIOD/$ORG"/_LIST.json ]]; then
        for element in $(jq '.[]' "$ROOT_DIR/$context/backup/$PERIOD/$ORG/_LIST".json | sed 's/\"//g'); do
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
#  pushAll
  rm -rf "$ROOT_DIR/$context/backup/$PERIOD" &>/dev/null
}

function uploads(){
    local branch
    local context
    local ORG
    local folder

    context="$1"
    createBranch 'backup/ALL'
    createBranch 'backup/UPLOAD'
    (
        cd "$GIT_FOLDER" || return
        for ORG in "${ORGS[@]}"; do
            branch="uploads/$ORG/$context"
            createBranch "$branch"
            mkdir -p "$GIT_FOLDER/$branch"
            cp "$ROOT_DIR/uploads/$context/$ORG/"${ORG}_${context}.* "$GIT_FOLDER/$branch"
            (
                cd "$ROOT_DIR/uploads/$context/$ORG"
                for folder in */; do cp -r "$folder" "$GIT_FOLDER/$branch/"; done
            )
            git add . &>/dev/null
            git commit -m "$context $PERIOD" &>/dev/null
            rm -rf ./*
        done
        git checkout 'backup/UPLOAD'
        git merge --squash "$branch" &>/dev/null
        git add .
        git commit -m "$context $PERIOD"
        git checkout --orphan 'auxiliar' 'backup/UPLOAD'
        git commit -m "UPLOAD $PERIOD"
        git checkout 'backup/ALL'
        git rebase 'auxiliar'
        git branch -D 'auxiliar'
        git tag -f "uploaad_$PERIOD" &>/dev/null
        pushAll
    )
}