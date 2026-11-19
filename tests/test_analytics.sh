#!/usr/bin/env bash
# Tests for 'apigee stats', 'apigee report' and 'apigee proxy stale'.
. "$(dirname "$0")/lib.sh"

test_stats_traffic_default_query() {
  use_x
  route GET '/environments/test/stats/apiproxy' 200 '{"environments":[{"name":"test"}]}'
  run "$APIGEE" stats traffic 2026-11-01 2026-11-19
  assert_status "ok" 0
  local log; log="$(cat "$FAKE_CURL_LOG")"
  assert_contains "dimension path" "$log" "/organizations/org1/environments/test/stats/apiproxy?"
  assert_contains "select" "$log" "select=sum%28message_count%29%2Csum%28is_error%29%2Ctps"
  assert_contains "range" "$log" "timeRange=11%2F01%2F2026%2000%3A00~11%2F19%2F2026%2000%3A00"
  assert_contains "output" "$OUT" '"name": "test"'
}

test_stats_traffic_by_other_dimension_and_unit() {
  use_x
  run "$APIGEE" stats traffic 2026-11-01 2026-11-19 --by developer_app --time-unit day
  assert_status "ok" 0
  local log; log="$(cat "$FAKE_CURL_LOG")"
  assert_contains "dimension" "$log" "/stats/developer_app?"
  assert_contains "unit" "$log" "timeUnit=day"
}

test_stats_query_takes_select_and_filters() {
  use_edge
  run "$APIGEE" stats query apiproxy,response_status_code --select 'sum(message_count)' --range 2026-11-01 2026-11-02 --limit 5
  assert_status "ok" 0
  local log; log="$(cat "$FAKE_CURL_LOG")"
  assert_contains "dimensions" "$log" "/stats/apiproxy%2Cresponse_status_code?"
  assert_contains "limit" "$log" "limit=5"
}

test_stats_rejects_bad_dates_and_missing_args() {
  use_x
  run "$APIGEE" stats traffic 11-01-2026 2026-11-19
  assert_status "bad date" 1
  assert_contains "says format" "$ERR" "YYYY-MM-DD"
  run "$APIGEE" stats traffic 2026-11-01
  assert_status "missing TO" 1
  run "$APIGEE" stats query apiproxy --range 2026-11-01 2026-11-02
  assert_status "missing select" 1
}

test_stats_is_read_only_even_with_dry_run() {
  use_x
  run "$APIGEE" -n stats traffic 2026-11-01 2026-11-19
  assert_status "ok" 0
}

test_report_list_and_get() {
  use_x
  route GET '/organizations/org1/reports$' 200 '{"qualifier":[{"name":"r1","displayName":"Traffic"}]}'
  route GET '/organizations/org1/reports/r1$' 200 '{"name":"r1","displayName":"Traffic"}'
  run "$APIGEE" report list
  assert_status "list" 0
  assert_contains "name" "$OUT" "r1"
  run "$APIGEE" report get r1
  assert_status "get" 0
  assert_contains "body" "$OUT" '"displayName": "Traffic"'
  run "$APIGEE" report get
  assert_status "missing id" 1
}

test_proxy_stale_lists_deployed_older_than_latest() {
  use_x
  route GET '/organizations/org1/apis$' 200 '{"proxies":[{"name":"a"},{"name":"b"},{"name":"c"}]}'
  route GET '/apis/a/revisions$' 200 '["1","2","3"]'
  route GET '/apis/b/revisions$' 200 '["1","2"]'
  route GET '/apis/c/revisions$' 200 '["1","2"]'
  route GET '/environments/test/apis/a/deployments$' 200 '{"deployments":[{"revision":"2"}]}'
  route GET '/environments/test/apis/b/deployments$' 200 '{"deployments":[{"revision":"2"}]}'
  route GET '/environments/test/apis/c/deployments$' 404 '{}'
  run "$APIGEE" proxy stale
  assert_status "ok" 0
  assert_eq "only a is stale" "a (latest: 3, deployed: 2)" "$OUT"
  run "$APIGEE" proxy stale --include-undeployed
  assert_eq "undeployed too" "a (latest: 3, deployed: 2)
c (latest: 2, deployed: none)" "$OUT"
}

run_tests
