#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"

makeDir
header
makeBackupList "$CONTEXT" 'list'
makeBackupSub "$CONTEXT/element"
makeBackupSub "$CONTEXT/element" 'pods'
makeBackupSub "$CONTEXT/element" 'keyvaluemaps'
makeBackupSub "$CONTEXT/element" 'resourcefiles'
makeBackupSubItem "$CONTEXT/element/keyvaluemaps/item" 'keyvaluemaps'
#makeBackupSubItem "$CONTEXT/element/keyvaluemaps/item" 'keyvaluemaps' 'keys'
copy
compress
[[ "$GIT" == 'ON' ]] &&  bash "git_$CONTEXT.sh"