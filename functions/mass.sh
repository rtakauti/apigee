#!/usr/bin/env bash

function mass() {
  activity 'organizations'
  activity 'environments'
  activity 'users'
  activity 'companies'
  activity 'apis'
  activity 'sharedflows'
  activity 'apps'
  activity 'apiproducts'
  activity 'developers'
  activity 'reports'
  activity 'userroles'
  activity 'targetservers'
  activity 'virtualhosts'
  activity 'caches'
  activity 'keyvaluemaps'
  activity 'keystores'
  activity 'references'
}

function activity() {
  local context

  context="$1"
  if [[ "$ACTIVITY" == 'clean' ]]; then
    clean "$context"
  else
    execute "$context"
  fi
}

function execute() {
  local context

  context="$1"
  (
    cd "$ROOT_DIR/$context" || return
    if [[ -f "${ACTIVITY}_${context}".sh ]]; then
      bash "${ACTIVITY}_${context}".sh
    fi
  )
}

function clean() {
  local context
  declare -a activities=("backup" "create" "update" "delete")

  context="$1"
  for activity in "${activities[@]}"; do
    if [[ -d "$context/$activity" ]]; then
      (
        cd "$context/$activity" || return
        rm -rf ./*
        rm -f ./*.*
      )
    fi
  done
}
