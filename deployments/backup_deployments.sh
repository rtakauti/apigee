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
  local rev
  local api_dir
  local query
  local sub_query
  local deploy
  local env_quantity
  local name

  name='deploy_'
  query='[.environment[].aPIProxy[] as $proxy | $proxy'
  query+=' | ($proxy.name)+"|"+.revision[].name] | unique | sort | .[]'
  echo "$expanded" | jq "$query" | sed 's/\"//g' |
    while IFS= read -r elements; do
      IFS='|' read -ra element <<<"$elements"
      rev=$(printf "%06d" "${element[1]}")
      api_dir="$ROOT_DIR/apis/backup/$DATE/$ORG/${element[0]}"
      mkdir -p "$api_dir"
      sub_query='[.environment[] as $envs | $envs.aPIProxy[]'
      sub_query+=" | select (.name==\"${element[0]}\") | .revision[] "
      sub_query+=" | {\"aPIProxy\":\"${element[0]}\", \"revision\":\"${element[1]}\", \"environment\":(select (.name==\"${element[1]}\")"
      sub_query+=" | .name=\$envs.name), \"organization\":\"$ORG\"}] | unique | sort"
      deploy=$(echo "$expanded" | jq "$sub_query")
      env_quantity=$(echo "$deploy" | jq 'length')
      env_quantity=$((env_quantity - 1))
      for index in $(seq 0 "$env_quantity"); do
        name+="$(echo "$deploy" | jq ".[$index].environment.name" | sed 's/\"//g')_"
      done
      echo "$deploy" >"$api_dir/${name}$rev.json"
      name='deploy_'
    done
}

function optimize() {
  local expanded

  expanded=$(cat <"backup/$DATE/$ORG/_EXPANDED.json")
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
