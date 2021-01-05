#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh
source ../organizations.sh

for ORG in ${ORGS[*]}; do
  makeDir
  update "organizations/$ORG/$CONTEXT"
  copy
done
compress
