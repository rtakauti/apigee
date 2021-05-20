#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

for ORG in "${ORGS[@]}"; do

  source "$ROOT_DIR/environments.sh"
  for ENV in "${ENVS[@]}"; do

    makeDir
    header
    makeBackupList "organizations/$ORG/environments/$ENV/$CONTEXT" 'list'
    makeBackupSub "organizations/$ORG/environments/$ENV/$CONTEXT/element"
#    makeBackupSub "organizations/$ORG/environments/$ENV/$CONTEXT/element" 'keys'
    makeBackupSubItem "organizations/$ORG/environments/$ENV/$CONTEXT/element/entries/item"
    copy

  done
done
compress
[[ "$GIT" == 'ON' ]] &&  bash "git_$CONTEXT.sh"
