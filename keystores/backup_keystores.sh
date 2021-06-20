#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

for ORG in "${ORGS[@]}"; do

  source "$ROOT_DIR/environments.sh"
  for ENV in "${ENVS[@]}"; do

    makeDir
    header
    makeBackupList "organizations/$ORG/environments/$ENV/$CONTEXT"
    cp "backup/$DATE/$ORG/$ENV/$CONTEXT.json" "backup/$DATE/$ORG/$ENV/LIST.json"
    makeBackupSub "organizations/$ORG/environments/$ENV/$CONTEXT/element"
    makeBackupSub "organizations/$ORG/environments/$ENV/$CONTEXT/element" 'aliases'
    makeBackupSub "organizations/$ORG/environments/$ENV/$CONTEXT/element" 'certs'
    makeBackupSubItem "organizations/$ORG/environments/$ENV/$CONTEXT/element/aliases/item" 'aliases'
    makeBackupSubItem "organizations/$ORG/environments/$ENV/$CONTEXT/element/aliases/item/certificate" 'aliases' 'certificate'
    makeBackupSubItem "organizations/$ORG/environments/$ENV/$CONTEXT/element/aliases/item/csr" 'aliases' 'csr'
    makeBackupSubItem "organizations/$ORG/environments/$ENV/$CONTEXT/element/certs/item" 'certs'
    makeBackupSubItem "organizations/$ORG/environments/$ENV/$CONTEXT/element/certs/item/export" 'certs' 'export'
  done
done
copy
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
