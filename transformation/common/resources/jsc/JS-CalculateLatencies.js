var request_start_time = context.getVariable('client.received.start.timestamp');
var target_start_time = context.getVariable('target.sent.end.timestamp');
var target_end_time = context.getVariable('target.received.start.timestamp');
var request_end_time = context.getVariable('system.timestamp');
var total_request_time = request_end_time-request_start_time;
var total_target_time = target_end_time-target_start_time;
var total_proxy_time = total_request_time-total_target_time;
context.setVariable('log.latency.request.total', total_request_time);
context.setVariable('log.latency.target', total_target_time);
context.setVariable('log.latency.proxy', total_proxy_time); 