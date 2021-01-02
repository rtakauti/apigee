#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh
source ../organizations.sh

for ORG in ${ORGS[*]}; do
  makeDir
  makeBackupList "organizations/$ORG/$CONTEXT" 'jq' '[[.qualifier[].name],[.qualifier[].displayName]] | transpose[] | .[0]+"|"+.[1]'
  makeBackupSub
  copy
done
compress
