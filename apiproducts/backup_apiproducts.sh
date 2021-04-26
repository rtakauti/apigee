#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh
source ../organizations.sh

for ORG in ${ORGS[*]}; do
  makeDir
  makeBackupList "organizations/$ORG/$CONTEXT?expand=true" 'expand'
  makeBackupList "organizations/$ORG/$CONTEXT" 'list'
  makeBackupSub "organizations/$ORG/$CONTEXT"
  copy
  compress
done
