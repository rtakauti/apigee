#!/usr/bin/env bash

source ../functions.sh
source ../env_var.sh
source ../organizations.sh

for ORG in ${ORGS[*]}; do
  makeDir
  delete "organizations/$ORG/$CONTEXT"
  copy
done
compress
