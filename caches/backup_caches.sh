#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh

makeDir
makeBackupList "environments/$ENV/$CONTEXT" 'list'
makeBackupSub
copy
compress
