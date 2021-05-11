#!/usr/bin/env bash

source ./env_var.sh

function createBundle() {
  local title
  local new_name

  (
    cd swaggers || exit
    for file in *.json; do
      title=$(jq '.info.title' "$file" | sed 's/ /-/g')
      jq --argjson title "$title" '.info.title=$title' "$file" >"$TEMP"
      cat "$TEMP" >"$file"
      title="${title//\"/}"
      createMainXML "$file" "$title"
      new_name="${file// /-}"
      if [[ ! -f "$new_name" ]]; then
        mv "$file" "$new_name"
      fi
    done
  )
}

function createMainXML() {
  local file
  local title
  local description
  declare -l basepath
  local version

  file="$1"
  title="$2"
  description=$(jq '.info.description' "$file" | sed 's/null//g' | sed 's/\"//g')
  version=$(jq '.info.version' "$file" | sed 's/null//g' | sed 's/\"//g')
  basepath="/$ORG/$title/$version"
  BUNDLE_DIR="$ROOT_DIR/bundles/$title/apiproxy"
  mkdir -p "$BUNDLE_DIR"
  createProxyXML "$basepath"
  createTargetXML
  cat <<EOF >"$BUNDLE_DIR/${title}.xml"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<APIProxy name="$title">
    <Basepaths>$basepath</Basepaths>
    <ConfigurationVersion majorVersion="4" minorVersion="0"/>
    <Description>$description</Description>
    <DisplayName>$title</DisplayName>
    <Policies/>
    <ProxyEndpoints>
        <ProxyEndpoint>default</ProxyEndpoint>
    </ProxyEndpoints>
    <Resources/>
    <Spec/>
    <TargetServers/>
    <TargetEndpoints>
        <TargetEndpoint>default</TargetEndpoint>
    </TargetEndpoints>
</APIProxy>
EOF
  (
    cd "$ROOT_DIR/zips" || exit
    7z a -r "$title".zip "$BUNDLE_DIR" >/dev/null
  )
}

function createProxyXML() {
  local basepath
  local proxy_dir

  basepath="$1"
  proxy_dir="$BUNDLE_DIR/proxies"
  mkdir -p "$proxy_dir"
  cat <<EOF >"$proxy_dir/default.xml"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ProxyEndpoint name="default">
  <PreFlow name="PreFlow">
    <Request/>
    <Response/>
  </PreFlow>
  <PostFlow name="PostFlow">
    <Request/>
    <Response/>
  </PostFlow>
  <Flows>
  $(createFlowXML)
  $(createPolicy 'RF-NotFound' 'Request' 'Flow')
  </Flows>
  <HTTPProxyConnection>
    <BasePath>$basepath</BasePath>
    <VirtualHost>default</VirtualHost>
  </HTTPProxyConnection>
  <RouteRule name="default">
    <TargetEndpoint>default</TargetEndpoint>
  </RouteRule>
</ProxyEndpoint>
EOF
}

function createFlowXML() {
  local verb
  local endpoint

  for endpoint in $(jq '.paths | keys[]' "$file"); do
    for verb in $(jq --argjson endpoint "$endpoint" '.paths[$endpoint] | keys[]' "$file"); do
      description=$(jq --argjson endpoint "$endpoint" --argjson verb "$verb" '.paths[$endpoint][$verb].description' "$file" | sed 's/null//g' | sed 's/\"//g')
      printf "\t<Flow name=%s>\n\t\t<Description>%s</Description>\n\t\t<Request/>\n\t\t<Response/>\n\t\t<Condition>(proxy.pathsuffix MatchesPath %s) and (request.verb = %s)</Condition>\n\t</Flow>\n" "$(echo "$endpoint" | sed ':a;N;$!ba;s/\n//g')" "$description" "$(echo "$endpoint" | sed 's/{[^}]*}/\*/g')" "$(echo "${verb^^}" | sed ':a;N;$!ba;s/\n//g')"
    done
  done
}

function createTargetXML() {
  local url
  local target_dir

  url=$(jq '.servers[0].url' "$file" | sed 's/null//g' | sed 's/\"//g')
  target_dir="$BUNDLE_DIR/targets"
  mkdir -p "$target_dir"
  cat <<EOF >"$target_dir/default.xml"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<TargetEndpoint name="default">
  <PreFlow name="PreFlow">
    <Request/>
    <Response/>
  </PreFlow>
  <Flows/>
  <PostFlow name="PostFlow">
    <Request/>
    <Response/>
  </PostFlow>
  <HTTPTargetConnection>
    <URL>$url</URL>
  </HTTPTargetConnection>
</TargetEndpoint>
EOF
}

function createPolicy() {
  local policy_dir
  local policy
  local type
  local position

  policy="$1"
  type="$2"
  position="$3"
  policy_dir="$BUNDLE_DIR/policies"
  mkdir -p "$policy_dir"
  cp "$ROOT_DIR/policies_dir/$policy.xml" "$policy_dir"
  if [[ "$position" == 'Flow' ]]; then
    printf "\t<Flow name=\"%s\">\n\t\t<%s>\n\t\t\t<Step>\n\t\t\t\t<Name>%s</Name>\n\t\t\t</Step>\n\t\t</%s>\n\t</Flow>\n" "$policy" "$type" "$policy" "$type"
  else
    printf "\t<Step>\n\t\t\t<Name>%s</Name>\n\t\t</Step>\n" "$policy"
  fi
}
