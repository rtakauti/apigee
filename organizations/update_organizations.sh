#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh

makeDir
header
update "$CONTEXT"
copy
compress
