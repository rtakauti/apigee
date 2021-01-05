#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh
source ../organizations.sh

for ORG in ${ORGS[*]}; do
  makeDir
  makeBackupList "organizations/$ORG/$CONTEXT" 'list'
  makeBackupList "organizations/$ORG/$CONTEXT?expand=true" 'jq' '[[.app[].appId],[.app[].name]] | transpose[] | .[0]+"|"+.[1]'
  makeBackupSub "organizations/$ORG/$CONTEXT" 'jq'
  copy
done
compress
