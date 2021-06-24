#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

function optimize() {
  local expanded
  local quantity
  local context

  expanded=$(cat <"backup/$DATE/$ORG/_EXPANDED.json")
  echo "$expanded" | jq '[.app[].name]' >"backup/$DATE/$ORG/_LIST.json"
  quantity=$(echo "$expanded" | jq '.app | length')
  for index in $(seq 0 $((quantity - 1))); do
    context=$(echo "$expanded" | jq ".app[$index]")
    echo "$context" >"backup/$DATE/$ORG/$(echo "$context" | jq ".name" | sed 's/\"//g')".json
  done
}

function hide() {
  jq '.app[].credentials[].consumerKey = "**********" | .app[].credentials[].consumerSecret = "**********"' "backup/$DATE/$ORG/_EXPANDED.json" >"backup/$DATE/TEMP.json"
  mv "backup/$DATE/TEMP.json" "backup/$DATE/$ORG/_EXPANDED.json"
}

for ORG in ${ORGS[*]}; do
  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT?expand=true" 'EXPANDED'
  hide
  makeBackupList "organizations/$ORG/$CONTEXT"
  optimize
  copy
done
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
