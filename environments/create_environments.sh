#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh

makeDir
create "organizations/$ORG/$CONTEXT"
copy
compress
