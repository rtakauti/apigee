#!/usr/bin/env bash

function totalArguments() {
  arguments=(
    --get
    --data-urlencode 'accuracy=100'
    --data-urlencode 'realtime=true'
    --data-urlencode 'sort=DESC'
    --data-urlencode 'tsAscending=true'
    --data-urlencode 'tzo=-180'
  )
}

function totalTrafficProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy"
  local query
  local TZ=GMT
  local file="total_traffic_proxies"
  declare -a arguments

  totalArguments
  arguments+=(--data-urlencode 'select=sum(message_count),sum(is_error)')
  arguments+=(--data-urlencode 'sortby=sum(message_count),sum(is_error)')
  arguments+=(--data-urlencode "$(date '+timeRange=01/01/2020 00:00:00~%m/%d/%Y %H:%M:%S')")
  arguments+=(--data-urlencode 'timeUnit=decade')
  makeCurl "${arguments[@]}"
  jq '.' "$TEMP" >"$report_dir/$file.json" &&
    status "$CURL_RESULT report total proxies see $report_dir/$file.json"
  echo 'Timestamp,Organization,Environment,Api Proxy, Total Traffic, Success Traffic, Error Traffic' >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric | $metric'
  query+=' | $metric[0].values | map(.value) as $total_traffic | $metric[1].values | map(.value) as $err | $total_traffic | to_entries'
  query+=" | map({tim:(\$metric[0].values[.key].timestamp as \$timestamp | \$timestamp / 1000 | strflocaltime(\"%Y-%m-%d %H:%M:%S+\") + (\$timestamp | tostring | .[10:13]))"
  query+=", org:\"$ORG\", environment:\$environment.name, name:\$dimension.name, tot:(.value | tonumber), succ:((\$total_traffic[(.key)] | tonumber)-(\$err[(.key)] | tonumber)), err:(\$err[.key] | tonumber)})[]]"
  query+=" | map(to_entries | map(.value) | @csv)[]"
  jq -r "$query" "$TEMP" | sed 's/\"//g' >>"$report_dir/$file.csv"
}

function monthlyTrafficProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy"
  local query
  local TZ=GMT
  local file="monthly_traffic_proxies"
  local total="sum(message_count)"
  local error="sum(is_error)"
  declare -a arguments

  totalArguments
  arguments+=(--data-urlencode 'select=sum(message_count),sum(is_error)')
  arguments+=(--data-urlencode 'sortby=sum(message_count),sum(is_error)')
  arguments+=(--data-urlencode "$(date '+timeRange=01/01/2020 00:00:00~%m/%d/%Y %H:%M:%S')")
  arguments+=(--data-urlencode 'timeUnit=month')
  makeCurl "${arguments[@]}"
  jq '.' "$TEMP" >"$report_dir/$file.json" &&
    status "$CURL_RESULT report monthly divided year proxies see $report_dir/$file.json"
  echo 'Timestamp,Organization,Environment,Api Proxy, Total Traffic, Success Traffic, Error Traffic' >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric | $metric'
  query+=' | $metric[0].values | map(.value) as $total_traffic | $metric[1].values | map(.value) as $err | $total_traffic | to_entries'
  query+=" | map({tim:(\$metric[0].values[.key].timestamp as \$timestamp | \$timestamp / 1000 | strflocaltime(\"%Y-%m-%d %H:%M:%S+\") + (\$timestamp | tostring | .[10:13]))"
  query+=", org:\"$ORG\", environment:\$environment.name, name:\$dimension.name, tot:(.value | tonumber), succ:((\$total_traffic[(.key)] | tonumber)-(\$err[(.key)] | tonumber)), err:(\$err[.key] | tonumber)})[]]"
  query+=" | map(to_entries | map(.value) | @csv)[]"
  jq -r "$query" "$TEMP" | sed 's/\"//g' >>"$report_dir/$file.csv"
}

function monthTrafficProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy"
  local query
  local TZ=GMT
  local file="month_traffic_proxies"
  local total="sum(message_count)"
  local error="sum(is_error)"
  declare -a arguments

  totalArguments
  arguments+=(--data-urlencode 'select=sum(message_count),sum(is_error)')
  arguments+=(--data-urlencode 'sortby=sum(message_count),sum(is_error)')
  arguments+=(--data-urlencode "$(date '+timeRange=%m/01/%Y 00:00:00~%m/%d/%Y %H:%M:%S')")
  arguments+=(--data-urlencode 'timeUnit=day')
  makeCurl "${arguments[@]}"
  jq '.' "$TEMP" >"$report_dir/$file.json" &&
    status "$CURL_RESULT report month period of proxies see $report_dir/$file.json"
  echo 'Timestamp,Organization,Environment,Api Proxy, Total Traffic, Success Traffic, Error Traffic' >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric | $metric'
  query+=' | $metric[0].values | map(.value) as $total_traffic | $metric[1].values | map(.value) as $err | $total_traffic | to_entries'
  query+=" | map({tim:(\$metric[0].values[.key].timestamp as \$timestamp | \$timestamp / 1000 | strflocaltime(\"%Y-%m-%d %H:%M:%S+\") + (\$timestamp | tostring | .[10:13]))"
  query+=", org:\"$ORG\", environment:\$environment.name, name:\$dimension.name, tot:(.value | tonumber), succ:((\$total_traffic[(.key)] | tonumber)-(\$err[(.key)] | tonumber)), err:(\$err[.key] | tonumber)})[]]"
  query+=" | map(to_entries | map(.value) | @csv)[]"
  jq -r "$query" "$TEMP" | sed 's/\"//g' >>"$report_dir/$file.csv"
}

function dayTrafficProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy"
  local query
  local TZ=GMT
  local file="day_traffic_proxies"
  declare -a arguments

  totalArguments
  arguments+=(--data-urlencode 'select=sum(message_count),sum(is_error)')
  arguments+=(--data-urlencode 'sortby=sum(message_count),sum(is_error)')
  arguments+=(--data-urlencode "$(date '+timeRange=%m/%d/%Y 00:00:00~%m/%d/%Y %H:%M:%S')")
  arguments+=(--data-urlencode 'timeUnit=hour')
  makeCurl "${arguments[@]}"
  jq '.' "$TEMP" >"$report_dir/$file.json" &&
    status "$CURL_RESULT report daily proxies see $report_dir/$file.json"
  echo 'Timestamp,Organization,Environment,Api Proxy, Total Traffic, Success Traffic, Error Traffic' >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric | $metric'
  query+=' | $metric[0].values | map(.value) as $total_traffic | $metric[1].values | map(.value) as $err | $total_traffic | to_entries'
  query+=' | map({tim:($metric[0].values[.key].timestamp as $timestamp | $timestamp / 1000 | strflocaltime("%Y-%m-%d %H:%M:%S+") + ($timestamp | tostring | .[10:13]))'
  query+=", org:\"$ORG\""
  query+=', environment:$environment.name, name:$dimension.name, tot:(.value | tonumber), succ:(($total_traffic[(.key)] | tonumber)-($err[(.key)] | tonumber)), err:($err[.key] | tonumber)})[]]'
  query+=" | map(to_entries | map(.value) | @csv)[]"
  jq -r "$query" "$TEMP" | sed 's/\"//g' >>"$report_dir/$file.csv"
}

function errorTrafficProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy,response_status_code,target_response_code"
  local query
  local TZ=GMT
  local file="error_traffic_proxies"
  declare -a arguments

  totalArguments
  arguments+=(--data-urlencode 'select=sum(is_error),sum(target_error)')
  arguments+=(--data-urlencode 'sortby=sum(is_error),sum(target_error)')
  arguments+=(--data-urlencode "$(date '+timeRange=%m/%d/%Y 00:00:00~%m/%d/%Y %H:%M:%S')")
  arguments+=(--data-urlencode 'filter=(response_status_code gt 399 or target_response_code gt 399)')
  arguments+=(--data-urlencode 'timeUnit=day')
  makeCurl "${arguments[@]}"
  jq '.' "$TEMP" >"$report_dir/$file.json" &&
    status "$CURL_RESULT report error daily proxies see $report_dir/$file.json"
  echo 'Timestamp,Organization,Environment,Api Proxy,Status Code,Proxy Error,Target Error' >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric | $metric'
  query+=' | $metric[0].values | map(.value) as $total_response_time | $metric[1].values | map(.value) as $target_response_time | $total_response_time | to_entries'
  query+=' | map({tim:($metric[0].values[.key].timestamp as $timestamp | $timestamp / 1000 | strflocaltime("%Y-%m-%d %H:%M:%S+") + ($timestamp | tostring | .[10:13]))'
  query+=", org:\"$ORG\""
  query+=', environment:$environment.name, name:($dimension.name | split(",") | .[0]), status:($dimension.name | split(",") | if .[1] != 0 then .[1] else .[2] end)'
  query+=', proxy:($metric[0].values[].value  | tonumber), target:($metric[1].values[].value  | tonumber)})[]]'
  query+=' | map(to_entries | map(.value) | @csv)[]'
  jq -r "$query" "$TEMP" | sed 's/\"//g' >>"$report_dir/$file.csv"
}

function topResponseTimeProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy,response_status_code"
  local query
  local TZ=GMT
  local file="top_response_time_proxies"
  declare -a arguments

  totalArguments
  arguments+=(--data-urlencode 'select=sum(message_count),avg(total_response_time),avg(target_response_time)')
  arguments+=(--data-urlencode 'sortby=sum(message_count),avg(total_response_time),avg(target_response_time)')
  arguments+=(--data-urlencode "$(date --date 'yesterday' '+timeRange=%m/%d/%Y %H:%M:%S~')$(date '+%m/%d/%Y %H:%M:%S')")
  arguments+=(--data-urlencode 'timeUnit=hour')
  #  arguments+=(--data-urlencode 'topk=5')
  makeCurl "${arguments[@]}"
  jq '.' "$TEMP" >"$report_dir/$file.json" &&
    status "$CURL_RESULT report top daily proxies see $report_dir/$file.json"
  echo 'Timestamp,Organization,Environment,Api Proxy,Response Status Code,Total Traffic,Total Response Time,Proxy Response Time,Target Response Time' >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric | $metric'
  query+=' | $metric[0].values | map(.value) as $total_traffic | $metric[1].values | map(.value) as $res | $metric[2].values | map(.value) as $target_response_time | $total_traffic | to_entries'
  query+=' | map({tim:($metric[0].values[.key].timestamp as $timestamp | $timestamp / 1000 | strflocaltime("%Y-%m-%d %H:%M:%S+") + ($timestamp | tostring | .[10:13]))'
  query+=", org:\"$ORG\""
  query+=', environment:$environment.name, name:($dimension.name | split(",") | .[0]), status:($dimension.name | split(",") | .[1]), tot:(.value | tonumber), res:($res[.key] | tonumber), pro:(($res[(.key)] | tonumber)-($target_response_time[(.key)] | tonumber)), tar:($target_response_time[.key] | tonumber)})[]]'
  query+=' | map(to_entries | map(.value) | @csv)[]'
  jq -r "$query" "$TEMP" | sed 's/\"//g' | awk 'BEGIN{ FS=OFS="," }NR>1{ $7=sprintf("%.2f",$7) }{ $8=sprintf("%.2f",$8) }{ $9=sprintf("%.2f",$9) }1' >>"$report_dir/$file.csv"
}

function testResponseTimeProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy,response_status_code,proxy_basepath,proxy_pathsuffix,request_verb"
  local query
  local title
  local awk_query
  local TZ=GMT
  local file="test_response_time_proxies"
  declare -a arguments

  totalArguments
  arguments+=(--data-urlencode 'select=sum(message_count),avg(total_response_time),avg(target_response_time),max(total_response_time),max(target_response_time),avg(response_size),max(response_size)')
  arguments+=(--data-urlencode 'sortby=sum(message_count),avg(total_response_time),avg(target_response_time),max(total_response_time),max(target_response_time),avg(response_size),max(response_size)')
  arguments+=(--data-urlencode "$(date --date 'yesterday' '+timeRange=%m/%d/%Y %H:%M:%S~')$(date '+%m/%d/%Y %H:%M:%S')")
  arguments+=(--data-urlencode 'timeUnit=hour')
  #  arguments+=(--data-urlencode 'topk=5')
  makeCurl "${arguments[@]}"
  jq '.' "$TEMP" >"$report_dir/$file.json" &&
    status "$CURL_RESULT report top daily proxies see $report_dir/$file.json"
  title='Timestamp,Organization,Environment,Api Proxy,Response Status Code'
  title+=',Basepath Endpoint,Request Verb'
  title+=',Total Traffic,AVG Proxy Response Time,AVG Target Response Time'
  title+=',AVG Total Response Time,MAX Target Response Time,MAX Total Response Time'
  title+=',AVG Response Size,MAX Response Size'
  echo "$title" >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric'
  query+=' | $metric | map(select(.name=="sum(message_count)").values[].timestamp)  as $timestamp'
  query+=' | $metric | map(select(.name=="sum(message_count)").values[].value)  as $total_traffic'
  query+=' | $metric | map(select(.name=="avg(total_response_time)").values[].value)  as $avg_total_response_time'
  query+=' | $metric | map(select(.name=="avg(target_response_time)").values[].value)  as $avg_target_response_time'
  query+=' | $metric | map(select(.name=="max(total_response_time)").values[].value)  as $max_total_response_time'
  query+=' | $metric | map(select(.name=="max(target_response_time)").values[].value)  as $max_target_response_time'
  query+=' | $metric | map(select(.name=="avg(response_size)").values[].value)  as $avg_response_size'
  query+=' | $metric | map(select(.name=="max(response_size)").values[].value)  as $max_response_size'
  query+=' | $timestamp | to_entries'
  query+=' | map({'
  query+='timestamp:(($timestamp[.key] / 1000 | strflocaltime("%Y-%m-%d %H:%M:%S+")) + ($timestamp | tostring | .[10:13]))'
  query+=", org:\"$ORG\""
  query+=', environment:$environment.name'
  query+=', apiproxy:($dimension.name | split(",") | .[0])'
  query+=', status_code:($dimension.name | split(",") | .[1])'
  query+=', basepath_endpoint:(($dimension.name | split(",") | .[2])+($dimension.name | split(",") | .[3]))'
  query+=', request_verb:($dimension.name | split(",") | .[4])'
  query+=', total_traffic:($total_traffic[.key] | tonumber)'
  query+=', avg_proxy_response_time:(($avg_total_response_time[.key] | tonumber)-($avg_target_response_time[.key] | tonumber))'
  query+=', avg_target_response_time:($avg_target_response_time[.key] | tonumber)'
  query+=', avg_total_response_time:($avg_total_response_time[.key] | tonumber)'
  query+=', max_target_response_time:($max_target_response_time[.key] | tonumber)'
  query+=', max_total_response_time:($max_total_response_time[.key] | tonumber)'
  query+=', avg_response_size:($avg_response_size[.key] | tonumber)'
  query+=', max_response_size:($max_response_size[.key] | tonumber)'
  query+='})[]]'
  query+=' | map(to_entries | map(.value) | @csv)[]'
  awk_query='BEGIN{ FS=OFS="," }NR>1'
  awk_query+='{ $9=sprintf("%.2f",$9) }{ $10=sprintf("%.2f",$10) }{ $11=sprintf("%.2f",$11) }'
  awk_query+='{ $14=sprintf("%.2f",$14) }1'
  jq -r "$query" "$TEMP" |
    sed 's/\"//g' |
    awk "$awk_query" >>"$report_dir/$file.csv"
}
