#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

setContext
rm -rf "$ROOT_DIR/uploads/$CONTEXT"

for ORG in ${ORGS[*]}; do

  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT?expand=true" 'EXPANDED'
  makeBackupList "organizations/$ORG/$CONTEXT"
  cp "backup/$DATE/$ORG/$CONTEXT.json" "backup/$DATE/$ORG/_LIST.json"
  makeBackupSub "organizations/$ORG/$CONTEXT/element"
  createDeploy
  transform
#  makeBackupSub "organizations/$ORG/$CONTEXT/element" 'attributes'
done
copy
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
