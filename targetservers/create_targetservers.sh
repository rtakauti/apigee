#!/usr/bin/env bash

source ../functions.sh
source ../env_var.sh
source ../environments.sh

for ENV in ${ENVS[*]}; do
  makeDir
  create "organizations/$ORG/environments/$ENV/$CONTEXT"
  copy
done
compress
