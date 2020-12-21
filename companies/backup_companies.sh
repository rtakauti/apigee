#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh

makeDir
makeBackupList "$CONTEXT?expand=true" 'expand'
makeBackupList "$CONTEXT" 'list'
makeBackupSub 'update'
copy
compress
