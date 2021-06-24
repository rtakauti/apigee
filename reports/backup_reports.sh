#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

function optimize() {
  local expanded
  local quantity
  local context

  expanded=$(cat <"backup/$DATE/$ORG/_EXPANDED.json")
  echo "$expanded" | jq '[.qualifier[].displayName]' >"backup/$DATE/$ORG/_LIST.json"
  quantity=$(echo "$expanded" | jq '.qualifier | length')
  for index in $(seq 0 $((quantity - 1))); do
    context=$(echo "$expanded" | jq ".qualifier[$index]")
    echo "$context" >"backup/$DATE/$ORG/$(echo "$context" | jq ".displayName" | sed 's/\"//g')".json
  done
}

for ORG in ${ORGS[*]}; do

  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT?expand=true" 'EXPANDED'
  makeBackupList "organizations/$ORG/$CONTEXT"
  optimize
  rearrangeFolder
done
copy
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
