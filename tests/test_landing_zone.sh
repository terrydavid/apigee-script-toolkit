#!/usr/bin/env bash
# setup/landing-zone.sh: plan/apply for Apigee X landing zones.
. "$(dirname "$0")/lib.sh"

LZ="$ROOT/setup/landing-zone.sh"
BASE=(--project p1 --region us-central1)

plan() { run "$LZ" plan "$@"; }

test_presets_are_listed() {
  run "$LZ" presets
  assert_status "presets" 0
  for p in eval-psc paid-peered paid-peered-shared paid-psc paid-psc-shared drz-us-psc drz-eu-psc-shared; do
    assert_contains "$p" "$OUT" "$p"
  done
}

test_eval_psc_plan() {
  plan --preset eval-psc "${BASE[@]}" --analytics-region us-central1
  assert_status "plan" 0
  assert_contains "billing" "$OUT" '"billingType":"EVALUATION"'
  assert_contains "no peering" "$OUT" '"disableVpcPeering":true'
  assert_contains "analytics" "$OUT" '"analyticsRegion":"us-central1"'
  assert_contains "accept list" "$OUT" '"consumerAcceptList":["p1"]'
  assert_not_contains "no peering connect" "$OUT" "vpc-peerings connect"
  assert_not_contains "no compute for eval" "$OUT" "compute.googleapis.com"
  assert_not_contains "no kms for eval" "$OUT" "kms keyrings"
  assert_not_contains "no drz" "$OUT" "controlPlaneEncryptionKeyName"
}

test_paid_peered_own_vpc_plan() {
  plan --preset paid-peered "${BASE[@]}" --analytics-region us-central1 --ip-range 10.100.0.0/22
  assert_status "plan" 0
  assert_contains "billing" "$OUT" '"billingType":"SUBSCRIPTION"'
  assert_contains "range" "$OUT" "compute addresses create apigee-range --global --prefix-length=22 --purpose=VPC_PEERING --network=apigee-net --project=p1"
  assert_contains "peering" "$OUT" "services vpc-peerings connect --service=servicenetworking.googleapis.com --network=apigee-net --ranges=apigee-range --project=p1"
  assert_contains "authorized network" "$OUT" '"authorizedNetwork":"projects/p1/global/networks/apigee-net"'
  assert_not_contains "peering not disabled" "$OUT" "disableVpcPeering"
  assert_contains "runtime key" "$OUT" '"runtimeDatabaseEncryptionKeyName":"projects/p1/locations/us-central1/keyRings/apigee-runtime/cryptoKeys/runtime-db"'
  assert_contains "instance range" "$OUT" '"ipRange"'
  assert_not_contains "no shared vpc" "$OUT" "shared-vpc"
}

test_paid_peered_shared_vpc_plan() {
  plan --preset paid-peered-shared "${BASE[@]}" --host-project host1 --analytics-region us-central1
  assert_status "plan" 0
  assert_contains "enable host" "$OUT" "compute shared-vpc enable host1"
  assert_contains "attach service" "$OUT" "compute shared-vpc associated-projects add p1 --host-project host1"
  assert_contains "range in host" "$OUT" "--network=apigee-net --project=host1"
  assert_contains "peering in host" "$OUT" "--network=apigee-net --ranges=apigee-range --project=host1"
  assert_contains "authorized network" "$OUT" '"authorizedNetwork":"projects/host1/global/networks/apigee-net"'
}

test_paid_psc_shared_vpc_with_external_lb() {
  plan --preset paid-psc-shared "${BASE[@]}" --host-project host1 --analytics-region us-central1 --exposure external --envgroup prod=api.example.com
  assert_status "plan" 0
  assert_contains "no peering" "$OUT" '"disableVpcPeering":true'
  assert_not_contains "no vpc peerings" "$OUT" "vpc-peerings connect"
  assert_not_contains "no servicenetworking for PSC" "$OUT" "servicenetworking"
  assert_contains "accept list" "$OUT" '"consumerAcceptList":["p1"]'
  assert_contains "neg" "$OUT" "compute network-endpoint-groups create apigee-psc-neg --network-endpoint-type=private-service-connect"
  assert_contains "shared subnet" "$OUT" "--subnet=projects/host1/regions/us-central1/subnetworks/apigee-subnet"
  assert_contains "external lb" "$OUT" "--load-balancing-scheme=EXTERNAL_MANAGED"
  assert_contains "managed cert" "$OUT" "compute ssl-certificates create apigee-cert --domains=api.example.com --global"
  assert_contains "envgroup" "$OUT" '"hostnames":["api.example.com"]'
}

test_drz_us_psc_plan() {
  plan --preset drz-us-psc "${BASE[@]}" --control-plane-location us --consumer-data-region us-central1
  assert_status "plan" 0
  assert_contains "regional endpoint" "$OUT" "APIGEE_CONTROL_PLANE_LOCATION=us"
  for k in apigee-control-plane apigee-consumer-data apigee-runtime apigee-disk; do
    assert_contains "keyring $k" "$OUT" "kms keyrings create $k"
  done
  assert_contains "cp key" "$OUT" '"controlPlaneEncryptionKeyName":"projects/p1/locations/us/keyRings/apigee-control-plane/cryptoKeys/control-plane"'
  assert_contains "consumer location" "$OUT" '"apiConsumerDataLocation":"us-central1"'
  assert_contains "consumer key" "$OUT" '"apiConsumerDataEncryptionKeyName"'
  assert_contains "disk key on instance" "$OUT" '"diskEncryptionKeyName":"projects/p1/locations/us-central1/keyRings/apigee-disk/cryptoKeys/runtime-disk"'
  assert_not_contains "no analyticsRegion" "$OUT" '"analyticsRegion"'
}

test_drz_eu_shared_vpc_warns_about_external_keys() {
  plan --preset drz-eu-psc-shared --project p1 --region europe-west4 --host-project host1 --control-plane-location eu --consumer-data-region europe-west4
  assert_status "plan" 0
  assert_contains "eu note" "$OUT$ERR" "external"
  assert_contains "cp location" "$OUT" "APIGEE_CONTROL_PLANE_LOCATION=eu"
}

test_validation() {
  plan --preset eval-psc "${BASE[@]}" --data-residency drz --control-plane-location us --consumer-data-region us-central1
  assert_status "eval + drz" 1
  assert_contains "why" "$ERR" "evaluation"
  plan --preset paid-psc-shared "${BASE[@]}" --analytics-region us-central1
  assert_status "shared without host" 1
  assert_contains "why host" "$ERR" "--host-project"
  plan --preset paid-peered "${BASE[@]}" --analytics-region us-central1 --exposure external
  assert_status "peered external" 1
  plan --preset paid-psc "${BASE[@]}" --analytics-region 'a;b'
  assert_status "bad characters" 1
  plan --preset paid-psc "${BASE[@]}"
  assert_status "analytics region required" 1
  plan --preset paid-psc --project p1 --analytics-region us-central1
  assert_status "region required" 1
  plan --preset drz-us-psc "${BASE[@]}"
  assert_status "drz needs locations" 1
}

test_apply_runs_gcloud_and_calls_the_api() {
  use_x
  export FAKE_GCLOUD_LOG="$T/gcloud.log"
  export APIGEE_WAIT_INTERVAL=0
  route POST '/organizations\?parent=projects/p1' 200 '{"name":"organizations/p1/operations/o1","done":false}'
  route GET '/operations/o1$' 200 '{"name":"organizations/p1/operations/o1","done":true}'
  run "$LZ" apply --preset paid-peered "${BASE[@]}" --analytics-region us-central1
  assert_status "needs confirmation" 1
  run "$LZ" apply --yes --preset paid-peered "${BASE[@]}" --analytics-region us-central1
  assert_status "apply" 0
  assert_contains "gcloud ran" "$(cat "$FAKE_GCLOUD_LOG")" "services enable apigee.googleapis.com"
  assert_contains "org created" "$(curl_log)" "=== POST https://apigee.googleapis.com/v1/organizations?parent=projects/p1"
  assert_contains "instance created" "$(curl_log)" "/organizations/p1/instances"
  assert_contains "env created" "$(curl_log)" "/organizations/p1/environments"
}

run_tests
