#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh

makeDir
update "$CONTEXT"
copy
compress
