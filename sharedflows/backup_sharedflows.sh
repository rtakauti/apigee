#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

setContext
rm -rf "$ROOT_DIR/uploads/$CONTEXT"
rm -rf "$ROOT_DIR/revisions/$CONTEXT"

for ORG in "${ORGS[@]}"; do

  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT" 'list'
  makeBackupSub "organizations/$ORG/$CONTEXT"
#  makeBackupSub "organizations/$ORG/$CONTEXT" 'revisions'
  copy

done
compress
[[ "$GIT" == 'ON' ]] &&  bash "git_$CONTEXT.sh"
