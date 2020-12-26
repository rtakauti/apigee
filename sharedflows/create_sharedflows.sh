#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh

makeDir
create "$CONTEXT"
copy
compress
