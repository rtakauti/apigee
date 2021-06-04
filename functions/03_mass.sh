#!/usr/bin/env bash

function mass() {
  activity 'organizations'
  activity 'users'
  activity 'deployments'
  activity 'environments'
  activity 'companies'
  activity 'developers'
  activity 'sharedflows'
  activity 'apis'
  activity 'apps'
  activity 'apiproducts'
  activity 'reports'
  activity 'userroles'
  activity 'targetservers'
  activity 'virtualhosts'
  activity 'flowhooks'
  activity 'caches'
  activity 'keyvaluemaps'
  activity 'keystores'
  activity 'references'
  activity 'stats'
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
  declare -a activities=("backup" "report")

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
