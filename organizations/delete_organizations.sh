#!/usr/bin/env bash

source ../functions.sh
source ../env_var.sh

makeDir
header
delete "$CONTEXT"
copy
compress