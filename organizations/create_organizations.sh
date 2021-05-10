#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh

makeDir
header
create "$CONTEXT"
copy
compress