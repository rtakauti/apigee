#!/usr/bin/env bash

source ../functions.sh
source ../env_var.sh
source ../organizations.sh

for ORG in ${ORGS[*]}; do
  makeDir
  header
  delete "organizations/$ORG/$CONTEXT"
  copy
  compress
done
