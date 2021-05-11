#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

for ORG in ${ORGS[*]}; do

  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT?expand=true" 'expand'
  makeBackupList "organizations/$ORG/$CONTEXT" 'list'
  makeBackupSub "organizations/$ORG/$CONTEXT" 'status'
  makeBackupSub "organizations/$ORG/$CONTEXT" 'list' 'developers'
  makeBackupSub "organizations/$ORG/$CONTEXT" 'list' 'apps'
  copy

done
compress
[[ "$GIT" == 'ON' ]] &&  bash "git_$CONTEXT.sh"
