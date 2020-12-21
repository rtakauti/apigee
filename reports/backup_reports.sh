#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh

makeDir
makeBackupList "$CONTEXT" 'jq' '[[.qualifier[].name],[.qualifier[].displayName]] | transpose[] | .[0]+"|"+.[1]'
makeBackupSub
copy
compress
