#!/usr/bin/env bash

source ../functions.sh
source ../env_var.sh

makeDir
delete "organizations/$ORG/$CONTEXT"
copy
compress