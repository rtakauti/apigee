#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

function optimize() {
  local expanded
  local quantity
  local context
  local app_name
  local backup_dir

  expanded=$(cat <"backup/$DATE/$ORG/_EXPANDED.json")
  echo "$expanded" | jq '[.app[].name]' >"backup/$DATE/$ORG/_LIST.json"
  quantity=$(echo "$expanded" | jq '.app | length')
  for index in $(seq 0 $((quantity - 1))); do
    context=$(echo "$expanded" | jq ".app[$index]")
    app_name=$(echo "$context" | jq ".name" | sed 's/\"//g')
    backup_dir="backup/$DATE/$ORG/$app_name"
    mkdir -p "$backup_dir"
    echo "$context" >"$backup_dir/$app_name".json
  done
}

function hide() {
  jq '.app[].credentials[].consumerKey = "**********" | .app[].credentials[].consumerSecret = "**********"' "backup/$DATE/$ORG/_EXPANDED.json" >"backup/$DATE/TEMP.json"
  mv "backup/$DATE/TEMP.json" "backup/$DATE/$ORG/_EXPANDED.json"
}

setContext
rm -rf "$ROOT_DIR/uploads/$CONTEXT"

for ORG in ${ORGS[*]}; do
  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT?expand=true" 'EXPANDED'
  hide
  makeBackupList "organizations/$ORG/$CONTEXT"
  optimize
  createDeploy
done
copy
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
