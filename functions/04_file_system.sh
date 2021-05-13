#!/usr/bin/env bash

function setFileContext() {

  if [[ "$CONTEXT" == 'organizations' ]]; then

    printf "export ORGS=(%s)\n" "$(echo "$ELEMENTS" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g')" >"$ROOT_DIR/organizations.sh"

  elif [[ "$CONTEXT" == 'environments' ]]; then

    read -r -d '' environments <<'EOF'
#!/usr/bin/env bash

#TROCAR

export ENVS

EOF
    [[ -f "$ROOT_DIR/environments.sh" ]] && environments=$(cat "$ROOT_DIR/environments.sh")

    elements="$ORG $(echo "$ELEMENTS" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g' | sed 's/\"//g')"
    if [[ "$environments" != *"$elements"* ]]; then
      printf 'if [[ "$ORG" == '%s' ]]; then' "$ORG" >"$TEMP"
      printf "\nENVS=(%s)\n" "$(echo "$ELEMENTS" | jq -c '.[]' | sed ':a;N;$!ba;s/\n/ /g')" >>"$TEMP"
      printf "fi\n" >>"$TEMP"
      echo "$environments" | sed $'/#TROCAR/{e cat $TEMP\n}' >"$ROOT_DIR/environments.sh"
      echo '#' "$elements" >>"$ROOT_DIR/environments.sh"
    fi
  fi
}
