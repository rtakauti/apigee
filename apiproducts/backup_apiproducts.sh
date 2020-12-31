#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh

makeDir
makeBackupList "organizations/$ORG/$CONTEXT?expand=true" 'expand'
makeBackupList "organizations/$ORG/$CONTEXT" 'list'
makeBackupSub
copy
compress