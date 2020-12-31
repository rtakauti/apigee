#!/usr/bin/env bash

source ../functions.sh
source ../env_var.sh
source ../environments.sh

for ENV in ${ENVS[*]}; do
  makeDir
  makeBackupList "organizations/$ORG/environments/$ENV/$CONTEXT" 'list'
  makeBackupSub
  copy
done
compress
