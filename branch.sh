#!/usr/bin/env bash

function delete_local() {
  local output
  local branches

  (
    cd git || exit
    git checkout master
    output=$(git branch)
    mapfile -t branches < <(echo "$output" |
      sed 's/*/ /g' |
      sed 's/ //g' |
      sed ':a;N;$!ba;s/master\n//g')
    for branch in "${branches[@]}"; do
      if [[ "$branch" != 'master' ]]; then
        git branch -D "$branch"
      fi
    done
  )
}

function delete_remote() {
  local output
  local branches

  (
    cd git || exit
    output=$(git branch -r)
    mapfile -t branches < <(echo "$output" |
      sed '1d' |
      sed 's/*/ /g' |
      sed 's/ //g' |
      sed 's/origin\///' |
      sed ':a;N;$!ba;s/origin\/master\n//g')
    for branch in "${branches[@]}"; do
      if [[ "$branch" != 'master' ]]; then
        git push origin -d "$branch"
      fi
    done
  )
}

delete_local
delete_remote
