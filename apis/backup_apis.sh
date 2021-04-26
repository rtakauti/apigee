#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh
source ../organizations.sh

rm -rf "$ROOT_DIR/uploads/$CONTEXT"
rm -rf "$ROOT_DIR/revisions/$CONTEXT"

for ORG in ${ORGS[*]}; do
  makeDir
  makeBackupList "organizations/$ORG/$CONTEXT" 'list'
  makeBackupSub "organizations/$ORG/$CONTEXT" 'revision'
  copy
  compress
done
