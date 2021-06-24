#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"
declare -a actions=(
  totalTrafficProxies
  monthlyTrafficProxies
  monthTrafficProxies
  dayTrafficProxies
  errorTrafficProxies
  overallDataProxies
)

makeDir
for ORG in "${ORGS[@]}"; do
  source "$ROOT_DIR/environments.sh"
  for ENV in "${ENVS[@]}"; do
    header
    report_dir="$ACTIVITY/$DATE/$ORG/$ENV"
    mkdir -p "$report_dir"
    for action in "${actions[@]}"; do $action; done
  done
done
copy
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
