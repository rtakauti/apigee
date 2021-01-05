#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh

makeDir
makeBackupList "$CONTEXT" 'list'
makeBackupSub "$CONTEXT"
copy
compress
