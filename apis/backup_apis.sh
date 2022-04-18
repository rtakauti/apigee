#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"
obj=""

setContext
rm -rf "$ROOT_DIR/uploads/$CONTEXT"
rm -rf "$ROOT_DIR/revisions/$CONTEXT"

for ORG in "${ORGS[@]}"; do

  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT"
  cp "backup/$DATE/$ORG/$CONTEXT.json" "backup/$DATE/$ORG/_LIST.json"
  createSShDeploy
  makeBackupSub "organizations/$ORG/$CONTEXT/element"
#  makeBackupSub "organizations/$ORG/$CONTEXT/element" 'deployments'
#  makeBackupSub "organizations/$ORG/$CONTEXT/element" 'keyvaluemaps'
#  makeBackupSubItem "organizations/$ORG/$CONTEXT/element/keyvaluemaps/item" 'keyvaluemaps'
#  makeBackupSubItem "organizations/$ORG/$CONTEXT/element/keyvaluemaps/item/keys" 'keyvaluemaps'
#
#  source "$ROOT_DIR/environments.sh"
#  for ENV in "${ENVS[@]}"; do
#    makeDir
#    header
#    makeBackupSub "organizations/$ORG/environments/$ENV/$CONTEXT/element" 'deployments'
#    makeBackupSub "organizations/$ORG/environments/$ENV/$CONTEXT/element/cachedlogs" 'categories'
#    makeBackupSubItem "organizations/$ORG/environments/$ENV/$CONTEXT/element/cachedlogs/categories/item" 'categories'
#  done
done
copy
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
