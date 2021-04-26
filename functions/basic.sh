#!/usr/bin/env bash

function discover() {
  ACTIVITY="$(echo "${0##*/}" | cut -d'_' -f1)"
  CONTEXT=$(basename "$(pwd)")
}
