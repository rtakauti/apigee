#!/usr/bin/env bash

source env_var.sh
source functions.sh

function deleteLocalBranch() {
  (
    cd "$ROOT_DIR/git" || return
    git checkout master
    git branch |
      grep -v '\*' |
      grep -v 'master' |
      while read -r branch; do
        git branch -D "$branch" &
        wait
      done
  )
}

function deleteRemoteBranch() {
  (
    cd "$ROOT_DIR/git" || return
    git branch -r |
      grep -v '\->' |
      grep -v 'master' |
      while read -r remote; do
        git push origin -d "${remote#origin/}" &
        wait
      done
  )
}

function deleteLocalTag() {
  (
    cd "$ROOT_DIR/git" || return
    git tag -l |
      while read -r tag; do
        git tag -d "$tag" &
        wait
      done
  )
}

function deleteRemoteTag() {
  (
    cd "$ROOT_DIR/git" || return
    git ls-remote --tags origin |
      sed -n -e 's/^.*refs//p' |
      while read -r tag; do
        git push origin ":refs$tag" &
        wait
      done
  )
}

deleteLocalBranch
deleteRemoteBranch
deleteLocalTag
deleteRemoteTag
rm -rf "$ROOT_DIR/git"
echo 'remove git folder'
