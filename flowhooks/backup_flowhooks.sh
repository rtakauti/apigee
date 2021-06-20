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
    copy

  done
done
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
