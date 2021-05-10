#!/usr/bin/env bash

source ../functions.sh
source ../env_var.sh
source ../organizations.sh

for ORG in "${ORGS[@]}"; do
  source ../environments.sh
  for ENV in "${ENVS[@]}"; do
    makeDir
    header
    delete "organizations/$ORG/environments/$ENV/$CONTEXT"
    copy
  done
  compress
done
