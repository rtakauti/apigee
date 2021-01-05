#!/usr/bin/env bash

source ../functions.sh
source ../env_var.sh
source ../organizations.sh
source ../environments.sh

for ORG in ${ORGS[*]}; do
  for ENV in ${ENVS[*]}; do
    makeDir
    makeBackupList "organizations/$ORG/environments/$ENV/$CONTEXT" 'list'
    makeBackupSub "organizations/$ORG/environments/$ENV/$CONTEXT"
    copy
  done
done
compress
