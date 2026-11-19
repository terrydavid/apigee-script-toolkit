#!/usr/bin/env bash
# apigee sa (service account for toolkit commands) and --impersonate
. "$(dirname "$0")/lib.sh"

test_sa_create_dry_run_previews_the_commands() {
  use_x
  run "$APIGEE" -n --org p1 sa create --name tk-sa1 --role roles/apigee.admin
  assert_status "dry run" 0
  assert_contains "account" "$OUT" "tk-sa1@p1.iam.gserviceaccount.com"
  assert_contains "role" "$OUT" "roles/apigee.admin"
}

test_sa_create_can_save_the_account_to_a_profile() {
  use_x
  export APIGEE_CONFIG_HOME="$T/cfg"
  run "$APIGEE" -y --org p1 sa create --name tk-sa1 --dry-run --save-profile sap
  assert_status "save" 0
  assert_contains "profile line" "$(cat "$T/cfg/profiles/sap.env")" "CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT=tk-sa1@p1.iam.gserviceaccount.com"
  assert_contains "org kept" "$(cat "$T/cfg/profiles/sap.env")" "APIGEE_ORG=p1"
}

test_sa_status_reports_the_impersonated_account() {
  use_x
  run "$APIGEE" --impersonate a@p1.iam.gserviceaccount.com sa status
  assert_status "status" 0
  assert_contains "shows" "$OUT" "a@p1.iam.gserviceaccount.com"
}

test_impersonate_flag_reaches_gcloud() {
  use_x
  run "$APIGEE" --impersonate a@p1.iam.gserviceaccount.com --org p1 proxy list
  assert_contains "env passed" "$(curl_log)" "impersonate=a@p1.iam.gserviceaccount.com"
}

test_impersonate_rejects_garbage() {
  use_x
  run "$APIGEE" --impersonate 'a;b' sa status
  assert_status "bad" 1
}

run_tests
