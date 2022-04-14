#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"

makeDir
header
makeBackupList "$CONTEXT"
cp "backup/$DATE/$CONTEXT.json" "backup/$DATE/_LIST.json"
makeBackupSub "$CONTEXT/element"
makeBackupSub "$CONTEXT/element" 'deployments'
makeBackupSub "$CONTEXT/element" 'pods'
makeBackupSub "$CONTEXT/element" 'keyvaluemaps'
rearrangeFolder
copy
compress
[[ "$GIT" == 'ON' ]] &&  bash "git_$CONTEXT.sh"