#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

for ORG in ${ORGS[*]}; do

  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT" 'list'
  makeBackupSub "organizations/$ORG/$CONTEXT/element"
  makeBackupSub "organizations/$ORG/$CONTEXT/element" 'servers'
  makeBackupSub "organizations/$ORG/$CONTEXT/element" 'deployments'
  makeBackupSub "organizations/$ORG/$CONTEXT/element" 'resourcefiles'
  copy

done
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
