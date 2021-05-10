#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

for ORG in ${ORGS[*]}; do

  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT" 'list'
  makeBackupList "organizations/$ORG/$CONTEXT?expand=true" 'jq' '[[.app[].appId],[.app[].name]] | transpose[] | .[0]+"|"+.[1]'
  makeBackupSub "organizations/$ORG/$CONTEXT" 'jq'
  copy

done
compress
[[ "$GIT" == 'ON' ]] &&  bash "git_$CONTEXT.sh"
