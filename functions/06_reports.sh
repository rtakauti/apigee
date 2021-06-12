#!/usr/bin/env bash

function totalArguments() {
  arguments=(
    --get
    --data-urlencode 'accuracy=100'
    --data-urlencode 'limit=14400'
    --data-urlencode 'realtime=true'
    --data-urlencode 'sort=DESC'
    --data-urlencode 'tsAscending=true'
    --data-urlencode 'tzo=-180'
  )
}

function totalTrafficProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy"
  local query
  local title
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
  title='Timestamp,Organization,Environment,Api Proxy'
  title+=',Success Traffic,Error Traffic,Total Traffic'
  echo "$title" >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric | $metric'
  query+=' | $metric | map(select(.name=="sum(message_count)").values[].timestamp)  as $timestamp'
  query+=' | $metric | map(select(.name=="sum(message_count)").values[].value)  as $total_traffic'
  query+=' | $metric | map(select(.name=="sum(is_error)").values[].value)  as $total_error'
  query+=' | $timestamp | to_entries'
  query+=' | map({'
  query+='timestamp:(($timestamp[.key] / 1000 | strflocaltime("%Y-%m-%d %H:%M:%S+")) + ($timestamp | tostring | .[10:13]))'
  query+=", org:\"$ORG\""
  query+=', environment:$environment.name'
  query+=', apiproxy:($dimension.name | split(",") | .[0])'
  query+=', total_success:(($total_traffic[.key] | tonumber)-($total_error[.key] | tonumber))'
  query+=', total_error:($total_error[.key] | tonumber)'
  query+=', total_traffic:($total_traffic[.key] | tonumber)'
  query+='})[]]'
  query+=' | sort_by(.apiproxy) | map(to_entries | map(.value) | @csv)[]'
  jq -r "$query" "$TEMP" | sed 's/\"//g' >>"$report_dir/$file.csv"
}

function monthlyTrafficProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy"
  local query
  local title
  local TZ=GMT
  local file="monthly_traffic_proxies"
  declare -a arguments

  totalArguments
  arguments+=(--data-urlencode 'select=sum(message_count),sum(is_error)')
  arguments+=(--data-urlencode 'sortby=sum(message_count),sum(is_error)')
  arguments+=(--data-urlencode "$(date '+timeRange=01/01/2020 00:00:00~%m/%d/%Y %H:%M:%S')")
  arguments+=(--data-urlencode 'timeUnit=month')
  makeCurl "${arguments[@]}"
  jq '.' "$TEMP" >"$report_dir/$file.json" &&
    status "$CURL_RESULT report monthly divided year proxies see $report_dir/$file.json"
  title='Timestamp,Organization,Environment,Api Proxy'
  title+=',Success Traffic,Error Traffic,Total Traffic'
  echo "$title" >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric | $metric'
  query+=' | $metric | map(select(.name=="sum(message_count)").values[].timestamp)  as $timestamp'
  query+=' | $metric | map(select(.name=="sum(message_count)").values[].value)  as $total_traffic'
  query+=' | $metric | map(select(.name=="sum(is_error)").values[].value)  as $total_error'
  query+=' | $timestamp | to_entries'
  query+=' | map({'
  query+='timestamp:(($timestamp[.key] / 1000 | strflocaltime("%Y-%m-%d %H:%M:%S+")) + ($timestamp | tostring | .[10:13]))'
  query+=", org:\"$ORG\""
  query+=', environment:$environment.name'
  query+=', apiproxy:($dimension.name | split(",") | .[0])'
  query+=', total_success:(($total_traffic[.key] | tonumber)-($total_error[.key] | tonumber))'
  query+=', total_error:($total_error[.key] | tonumber)'
  query+=', total_traffic:($total_traffic[.key] | tonumber)'
  query+='}) | map(select(.total_traffic > 0))[]]'
  query+=' | sort_by(.apiproxy) | map(to_entries | map(.value) | @csv)[]'
  jq -r "$query" "$TEMP" | sed 's/\"//g' >>"$report_dir/$file.csv"
}

function monthTrafficProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy"
  local query
  local title
  local TZ=GMT
  local file="month_traffic_proxies"
  declare -a arguments

  totalArguments
  arguments+=(--data-urlencode 'select=sum(message_count),sum(is_error)')
  arguments+=(--data-urlencode 'sortby=sum(message_count),sum(is_error)')
  arguments+=(--data-urlencode "$(date '+timeRange=%m/01/%Y 00:00:00~%m/%d/%Y %H:%M:%S')")
  arguments+=(--data-urlencode 'timeUnit=day')
  makeCurl "${arguments[@]}"
  jq '.' "$TEMP" >"$report_dir/$file.json" &&
    status "$CURL_RESULT report month period of proxies see $report_dir/$file.json"
  title='Timestamp,Organization,Environment,Api Proxy'
  title+=',Success Traffic,Error Traffic,Total Traffic'
  echo "$title" >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric | $metric'
  query+=' | $metric | map(select(.name=="sum(message_count)").values[].timestamp)  as $timestamp'
  query+=' | $metric | map(select(.name=="sum(message_count)").values[].value)  as $total_traffic'
  query+=' | $metric | map(select(.name=="sum(is_error)").values[].value)  as $total_error'
  query+=' | $timestamp | to_entries'
  query+=' | map({'
  query+='timestamp:(($timestamp[.key] / 1000 | strflocaltime("%Y-%m-%d %H:%M:%S+")) + ($timestamp | tostring | .[10:13]))'
  query+=", org:\"$ORG\""
  query+=', environment:$environment.name'
  query+=', apiproxy:($dimension.name | split(",") | .[0])'
  query+=', total_success:(($total_traffic[.key] | tonumber)-($total_error[.key] | tonumber))'
  query+=', total_error:($total_error[.key] | tonumber)'
  query+=', total_traffic:($total_traffic[.key] | tonumber)'
  query+='}) | map(select(.total_traffic > 0))[]]'
  query+=' | sort_by(.apiproxy) | map(to_entries | map(.value) | @csv)[]'
  jq -r "$query" "$TEMP" | sed 's/\"//g' >>"$report_dir/$file.csv"
}

function dayTrafficProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy"
  local query
  local title
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
  title='Timestamp,Organization,Environment,Api Proxy'
  title+=',Success Traffic,Error Traffic,Total Traffic'
  echo "$title" >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric | $metric'
  query+=' | $metric | map(select(.name=="sum(message_count)").values[].timestamp)  as $timestamp'
  query+=' | $metric | map(select(.name=="sum(message_count)").values[].value)  as $total_traffic'
  query+=' | $metric | map(select(.name=="sum(is_error)").values[].value)  as $total_error'
  query+=' | $timestamp | to_entries'
  query+=' | map({'
  query+='timestamp:(($timestamp[.key] / 1000 | strflocaltime("%Y-%m-%d %H:%M:%S+")) + ($timestamp | tostring | .[10:13]))'
  query+=", org:\"$ORG\""
  query+=', environment:$environment.name'
  query+=', apiproxy:($dimension.name | split(",") | .[0])'
  query+=', total_success:(($total_traffic[.key] | tonumber)-($total_error[.key] | tonumber))'
  query+=', total_error:($total_error[.key] | tonumber)'
  query+=', total_traffic:($total_traffic[.key] | tonumber)'
  query+='}) | map(select(.total_traffic > 0))[]]'
  query+=' | sort_by(.apiproxy) | map(to_entries | map(.value) | @csv)[]'
  jq -r "$query" "$TEMP" | sed 's/\"//g' >>"$report_dir/$file.csv"
}

function errorTrafficProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy,response_status_code,target_response_code"
  local query
  local title
  local TZ=GMT
  local file="error_traffic_proxies"
  declare -a arguments

  totalArguments
  arguments+=(--data-urlencode 'select=sum(is_error),sum(target_error)')
  arguments+=(--data-urlencode 'sortby=sum(is_error),sum(target_error)')
  arguments+=(--data-urlencode 'filter=(response_status_code gt 399 or target_response_code gt 399)')
  arguments+=(--data-urlencode "$(date '+timeRange=%m/%d/%Y 00:00:00~%m/%d/%Y %H:%M:%S')")
  arguments+=(--data-urlencode 'timeUnit=day')
  makeCurl "${arguments[@]}"
  jq '.' "$TEMP" >"$report_dir/$file.json" &&
    status "$CURL_RESULT report error daily proxies see $report_dir/$file.json"
  title='Timestamp,Organization,Environment,Api Proxy'
  title+=',Response Status Code,Proxy Error,Target Error,Total Error'
  echo "$title" >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric | $metric'
  query+=' | $metric | map(select(.name=="sum(is_error)").values[].timestamp)  as $timestamp'
  query+=' | $metric | map(select(.name=="sum(is_error)").values[].value)  as $total_error'
  query+=' | $metric | map(select(.name=="sum(target_error)").values[].value)  as $target_error'
  query+=' | $timestamp | to_entries'
  query+=' | map({'
  query+='timestamp:(($timestamp[.key] / 1000 | strflocaltime("%Y-%m-%d %H:%M:%S+")) + ($timestamp | tostring | .[10:13]))'
  query+=", org:\"$ORG\""
  query+=', environment:$environment.name'
  query+=', apiproxy:($dimension.name | split(",") | .[0])'
  query+=', status_code:($dimension.name | split(",") | if .[1] != 0 then .[1] else .[2] end)'
  query+=', proxy_error:(($total_error[.key] | tonumber)-($target_error[.key] | tonumber))'
  query+=', target_error:($target_error[.key] | tonumber)'
  query+=', total_error:($total_error[.key] | tonumber)'
  query+='})[]]'
  query+=' | sort_by(.apiproxy) | map(to_entries | map(.value) | @csv)[]'
  jq -r "$query" "$TEMP" | sed 's/\"//g' >>"$report_dir/$file.csv"
}

function overallDataProxies() {
  local URI="organizations/$ORG/environments/$ENV/$CONTEXT/apiproxy,response_status_code,proxy_basepath,proxy_pathsuffix,request_verb,client_id,proxy_client_ip"
  local query
  local title
  local metrics
  local TZ=GMT
  local file="overall_data_proxies"
  declare -a arguments

  totalArguments
  metrics='sum(message_count),avg(total_response_time),avg(target_response_time)'
  metrics+=',max(total_response_time),max(target_response_time)'
  metrics+=',avg(request_size),max(request_size)'
  metrics+=',avg(response_size),max(response_size)'
  metrics+=',sum(is_error),sum(target_error)'
  arguments+=(--data-urlencode "select=$metrics")
  arguments+=(--data-urlencode "sortby=$metrics")
  arguments+=(--data-urlencode "$(date --date 'yesterday' '+timeRange=%m/%d/%Y %H:%M:%S~')$(date '+%m/%d/%Y %H:%M:%S')")
  arguments+=(--data-urlencode 'timeUnit=hour')
  #  arguments+=(--data-urlencode 'topk=5')
  makeCurl "${arguments[@]}"
  jq '.' "$TEMP" >"$report_dir/$file.json" &&
    status "$CURL_RESULT report overall daily proxies see $report_dir/$file.json"
  title='Timestamp,Organization,Environment,Api Proxy'
  title+=',Response Status Code,Subscription Key,Client IP'
  title+=',Basepath Endpoint,Request Verb,Total Traffic'
  title+=',AVG Proxy Response Time,AVG Target Response Time,AVG Total Response Time'
  title+=',MAX Proxy Response Time,MAX Target Response Time,MAX Total Response Time'
  title+=',AVG Request Size,MAX Request Size'
  title+=',AVG Response Size,MAX Response Size'
  title+=',Proxy Error,Target Error,Total Error'
  echo "$title" >>"$report_dir/$file.csv"
  query='[.environments[] | . as $environment | .dimensions[] | . as $dimension | .metrics |. as $metric'
  query+=' | $metric | map(select(.name=="sum(message_count)").values[].timestamp)  as $timestamp'
  query+=' | $metric | map(select(.name=="sum(message_count)").values[].value)  as $total_traffic'
  query+=' | $metric | map(select(.name=="avg(total_response_time)").values[].value)  as $avg_total_response_time'
  query+=' | $metric | map(select(.name=="avg(target_response_time)").values[].value)  as $avg_target_response_time'
  query+=' | $metric | map(select(.name=="max(total_response_time)").values[].value)  as $max_total_response_time'
  query+=' | $metric | map(select(.name=="max(target_response_time)").values[].value)  as $max_target_response_time'
  query+=' | $metric | map(select(.name=="avg(request_size)").values[].value)  as $avg_request_size'
  query+=' | $metric | map(select(.name=="max(request_size)").values[].value)  as $max_request_size'
  query+=' | $metric | map(select(.name=="avg(response_size)").values[].value)  as $avg_response_size'
  query+=' | $metric | map(select(.name=="max(response_size)").values[].value)  as $max_response_size'
  query+=' | $metric | map(select(.name=="sum(is_error)").values[].value)  as $total_error'
  query+=' | $metric | map(select(.name=="sum(target_error)").values[].value)  as $target_error'
  query+=' | $timestamp | to_entries'
  query+=' | map(. as $data | $data | (if ($total_traffic[.key] | tonumber | round) == 0 then "No Requests Made" else ($total_traffic[.key] | tonumber | round) end) as $traffic'
  query+=' | $data | {'
  query+='timestamp:(($timestamp[.key] / 1000 | strflocaltime("%Y-%m-%d %H:%M:%S+")) + ($timestamp | tostring | .[10:13]))'
  query+=", org:\"$ORG\""
  query+=', environment:$environment.name'
  query+=', apiproxy:($dimension.name | split(",") | .[0])'
  query+=', status_code:($dimension.name | split(",") | .[1])'
  query+=', subscription_key:(if ($dimension.name | split(",") | .[5]) == "(not set)" then "No Subscription Key" else ($dimension.name | split(",") | .[5]) end)'
  query+=', client_ip:($dimension.name | split(",") | .[6])'
  query+=', basepath_endpoint:(($dimension.name | split(",") | .[2])+($dimension.name | split(",") | .[3]))'
  query+=', request_verb:($dimension.name | split(",") | .[4])'
  query+=', total_traffic:(if $traffic == "No Requests Made" then "No Requests Made" else ($total_traffic[.key] | tonumber | round) end)'
  query+=', avg_proxy_response_time:(if $traffic == "No Requests Made" then "No Requests Made" else (($avg_total_response_time[.key] | tonumber)-($avg_target_response_time[.key] | tonumber) | round) end)'
  query+=', avg_target_response_time:(if $traffic == "No Requests Made" then "No Requests Made" else ($avg_target_response_time[.key] | tonumber | round) end)'
  query+=', avg_total_response_time:(if $traffic == "No Requests Made" then "No Requests Made" else ($avg_total_response_time[.key] | tonumber | round) end)'
  query+=', max_proxy_response_time:(if $traffic == "No Requests Made" then "No Requests Made" else (($max_total_response_time[.key] | tonumber)-($max_target_response_time[.key] | tonumber) | round) end)'
  query+=', max_target_response_time:(if $traffic == "No Requests Made" then "No Requests Made" else ($max_target_response_time[.key] | tonumber | round) end)'
  query+=', max_total_response_time:(if $traffic == "No Requests Made" then "No Requests Made" else ($max_total_response_time[.key] | tonumber | round) end)'
  query+=', avg_request_size:(if $traffic == "No Requests Made" then "No Requests Made" else ($avg_request_size[.key] | tonumber | round) end)'
  query+=', max_request_size:(if $traffic == "No Requests Made" then "No Requests Made" else ($max_request_size[.key] | tonumber | round) end)'
  query+=', avg_response_size:(if $traffic == "No Requests Made" then "No Requests Made" else ($avg_response_size[.key] | tonumber | round) end)'
  query+=', max_response_size:(if $traffic == "No Requests Made" then "No Requests Made" else ($max_response_size[.key] | tonumber | round) end)'
  query+=', proxy_error:(if $traffic == "No Requests Made" then "No Requests Made" else (if ($dimension.name | split(",") | .[1] | tonumber) < 400 then "No Errors Found" else (($total_error[.key] | tonumber)-($target_error[.key] | tonumber) | round) end) end)'
  query+=', target_error:(if $traffic == "No Requests Made" then "No Requests Made" else (if ($dimension.name | split(",") | .[1] | tonumber) < 400 then "No Errors Found" else ($target_error[.key] | tonumber | round) end) end)'
  query+=', total_error:(if $traffic == "No Requests Made" then "No Requests Made" else (if ($dimension.name | split(",") | .[1] | tonumber) < 400 then "No Errors Found" else ($total_error[.key] | tonumber | round) end) end)'
  query+='})'
#  query+=' | map(select(.total_traffic!="No Requests Made"))'
  query+='[]]'
  query+=' | sort_by(.apiproxy,.status_code) | map(to_entries | map(.value) | @csv)[]'
  jq -r "$query" "$TEMP" | sed 's/\"//g' >>"$report_dir/$file.csv"
}

