#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

for ORG in ${ORGS[*]}; do

  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT"
  cp "backup/$DATE/$ORG/$CONTEXT.json" "backup/$DATE/$ORG/_LIST.json"
  makeBackupSub "organizations/$ORG/$CONTEXT/element"
  makeBackupSub "organizations/$ORG/$CONTEXT/element" 'servers'
  rearrangeFolder
  copy

done
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
