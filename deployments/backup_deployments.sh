#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"

function environment() {
  local quantity
  local environment

  quantity=$(echo "$expanded" | jq '.environment | length')
  quantity=$((quantity - 1))
  [[ "$quantity" -lt 0 ]] && return
  environment_dir="$ROOT_DIR/environments/backup/$DATE/$ORG/deployments"
  mkdir -p "$environment_dir"
  for index in $(seq 0 "$quantity"); do
    environment=$(echo "$expanded" | jq ".environment[$index]" | jq ". + {organization:\"$ORG\"}")
    echo "$environment" >"$environment_dir/$(echo "$environment" | jq ".name" | sed 's/\"//g')".json
  done
}

function api() {
  local list
  local rev
  local api_dir

  list=$(echo "$expanded" |
    jq '[.environment[].aPIProxy[] as $proxy | $proxy | ($proxy.name)+"|"+.revision[].name] | unique | sort')
  echo "$list" | jq '.[]' | sed 's/\"//g' |
    while IFS= read -r elements; do
      IFS='|' read -ra element <<<"$elements"
      rev=$(printf "%06d" "${element[1]}")
      api_dir="$ROOT_DIR/apis/backup/$DATE/$ORG/deployments/${element[0]}"
      mkdir -p "$api_dir"
      echo "$expanded" |
        jq "[.environment[] as \$envs | \$envs.aPIProxy[]  | select (.name==\"${element[0]}\") | .revision[] | {\"aPIProxy\":\"${element[0]}\", \"revision\":\"${element[1]}\", \"environment\":(select (.name==\"${element[1]}\") | .name=\$envs.name), \"organization\":\"$ORG\"}] | unique | sort" >"$api_dir/revision_$rev.json"
    done
}

function optimize() {
  local expanded

  expanded=$(cat <"backup/$DATE/$ORG/EXPANDED.json")
  environment
  api
}

for ORG in ${ORGS[*]}; do
  makeDir
  header
  makeBackupList "organizations/$ORG/$CONTEXT" 'EXPANDED'
  optimize
  copy
done
compress
[[ "$GIT" == 'ON' ]] && bash "git_$CONTEXT.sh"
