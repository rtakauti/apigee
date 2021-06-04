#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"

function optimize() {
  jq '[.user[].name]' "backup/$DATE/$CONTEXT.json" >"backup/$DATE/LIST.json"
  cp "backup/$DATE/LIST.json" "backup/$DATE/$CONTEXT.json"
}

makeDir
header
makeBackupList "$CONTEXT"
optimize
makeBackupSub "$CONTEXT/element"
makeBackupSub "$CONTEXT/element" 'apps'
makeBackupSubItem "$CONTEXT/element/apps/item" 'apps'
makeBackupSubItem "$CONTEXT/element/apps/item" 'apps' 'attributes'
copy
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
