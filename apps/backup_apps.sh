#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

for ORG in ${ORGS[*]}; do

  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT" 'list'
  makeBackupList "organizations/$ORG/$CONTEXT?expand=true" 'expand'
  makeBackupSub "organizations/$ORG/$CONTEXT/element"
  copy

done
compress
[[ "$GIT" == 'ON' ]] &&  bash "git_$CONTEXT.sh"
