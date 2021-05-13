#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"

makeDir
header
makeBackupList "$CONTEXT" 'list'
makeBackupSub "$CONTEXT"
makeBackupSub "$CONTEXT" 'pods'
copy
compress
[[ "$GIT" == 'ON' ]] &&  bash "git_$CONTEXT.sh"