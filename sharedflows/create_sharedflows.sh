#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh
source ../organizations.sh

for ORG in ${ORGS[*]}; do
  makeDir
  create "organizations/$ORG/$CONTEXT"
  copy
  compress
done
