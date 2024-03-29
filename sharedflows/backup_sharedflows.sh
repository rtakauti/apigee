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
  makeBackupList "organizations/$ORG/$CONTEXT"
  cp "backup/$DATE/$ORG/$CONTEXT.json" "backup/$DATE/$ORG/_LIST.json"
  makeBackupSub "organizations/$ORG/$CONTEXT/element"
#  makeBackupSub "organizations/$ORG/$CONTEXT/element" 'deployments'
#
#  source "$ROOT_DIR/environments.sh"
#  for ENV in "${ENVS[@]}"; do
#    makeBackupSub "organizations/$ORG/environments/$ENV/$CONTEXT/element" 'deployments'
#  done
done
copy
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
