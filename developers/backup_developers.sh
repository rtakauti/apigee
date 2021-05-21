#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

for ORG in ${ORGS[*]}; do

  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT?expand=true" 'expand'
  makeBackupList "organizations/$ORG/$CONTEXT" 'list'
  makeBackupSub "organizations/$ORG/$CONTEXT/element" 'attributes'
  makeBackupSub "organizations/$ORG/$CONTEXT/element" 'apps'
  makeBackupSubItem "organizations/$ORG/$CONTEXT/element/attributes/item" 'attributes'
  copy

done
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
