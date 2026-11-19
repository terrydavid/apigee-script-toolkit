#!/usr/bin/env bash
# Apigee X landing zones: plan or apply a preset (peered or PSC, own or Shared VPC,
# optional data residency + CMEK, optional external load balancer).
#   setup/landing-zone.sh presets
#   setup/landing-zone.sh plan  --preset NAME --project P --region R [options]
#   setup/landing-zone.sh apply --preset NAME ... --yes
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APIGEE="${APIGEE_BIN:-$ROOT/bin/apigee}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

presets() {
  cat <<'EOF'
eval-psc            Evaluation org, PSC (no VPC peering), no CMEK. Free trial; no data residency.
paid-peered         Paid org, VPC peering to your own VPC, runtime CMEK.
paid-peered-shared  Paid org, VPC peering to a Shared VPC host project (--host-project).
paid-psc            Paid org, PSC (disableVpcPeering), runtime CMEK. Optional external LB.
paid-psc-shared     Paid org, PSC, subnet in a Shared VPC host project (--host-project).
drz-us-psc          Data residency (control plane + consumer data in-region), PSC, full CMEK.
drz-eu-psc-shared   Data residency in the EU, PSC, Shared VPC, full CMEK.
EOF
}

usage() {
  cat <<'EOF'
Usage: landing-zone.sh presets
       landing-zone.sh plan|apply --preset NAME --project P --region R [options]
Options:
  --analytics-region R        required unless data residency
  --host-project H            Shared VPC host (required by *-shared presets)
  --network NAME              VPC name (default apigee-net)
  --ip-range CIDR[,CIDR]      peered: instance ipRange (default: Google allocates)
  --exposure none|external    PSC only: build an external HTTPS load balancer
  --envgroup NAME=HOSTNAME    create envgroup + environment of that name
  --env NAME                  environment when no envgroup (default dev)
  --instance NAME             default instance-REGION
  --control-plane-location L  data residency, for example us or eu
  --consumer-data-region R    data residency consumer data region
  --data-residency none|drz   override the preset
  --yes                       apply without prompting
EOF
}

MODE="${1:-}"; [[ -n "$MODE" ]] || { usage >&2; exit 1; }
shift || true
case "$MODE" in
  presets) presets; exit 0 ;;
  -h|--help|help) usage; exit 0 ;;
  plan|apply) ;;
  *) die "unknown command '$MODE'" ;;
esac

PRESET="" PROJECT="" REGION="" ANALYTICS="" HOST="" NET="apigee-net" IPRANGE="" EXPOSURE="none"
ENVGROUP="" ENVGROUP_HOST="" ENVNAME="dev" INSTANCE="" CPLOC="" CDREGION="" DRZ="" YES=""
while (($#)); do
  case "$1" in
    --preset) PRESET="${2:-}"; shift 2 ;;
    --project) PROJECT="${2:-}"; shift 2 ;;
    --region) REGION="${2:-}"; shift 2 ;;
    --analytics-region) ANALYTICS="${2:-}"; shift 2 ;;
    --host-project) HOST="${2:-}"; shift 2 ;;
    --network) NET="${2:-}"; shift 2 ;;
    --ip-range) IPRANGE="${2:-}"; shift 2 ;;
    --exposure) EXPOSURE="${2:-}"; shift 2 ;;
    --envgroup) ENVGROUP="${2%%=*}"; ENVGROUP_HOST="${2#*=}"; [[ "$2" == *=* ]] || die "--envgroup needs NAME=HOSTNAME"; shift 2 ;;
    --env) ENVNAME="${2:-}"; shift 2 ;;
    --instance) INSTANCE="${2:-}"; shift 2 ;;
    --control-plane-location) CPLOC="${2:-}"; shift 2 ;;
    --consumer-data-region) CDREGION="${2:-}"; shift 2 ;;
    --data-residency) DRZ="${2:-}"; shift 2 ;;
    --yes) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option '$1'" ;;
  esac
done

# ---- preset -> traits
BILLING=SUBSCRIPTION PEERED=0 SHARED=0 CMEK=1 DRZ_DEFAULT=none
case "$PRESET" in
  eval-psc) BILLING=EVALUATION CMEK=0 ;;
  paid-peered) PEERED=1 ;;
  paid-peered-shared) PEERED=1 SHARED=1 ;;
  paid-psc) ;;
  paid-psc-shared) SHARED=1 ;;
  drz-us-psc) DRZ_DEFAULT=drz ;;
  drz-eu-psc-shared) DRZ_DEFAULT=drz SHARED=1 ;;
  "") die "--preset is required (see: landing-zone.sh presets)" ;;
  *) die "unknown preset '$PRESET'" ;;
esac
DRZ="${DRZ:-$DRZ_DEFAULT}"

# ---- validation
for v in PROJECT REGION ANALYTICS HOST NET IPRANGE ENVGROUP ENVGROUP_HOST ENVNAME INSTANCE CPLOC CDREGION; do
  [[ -z "${!v}" || "${!v}" =~ ^[A-Za-z0-9._/,-]+$ ]] || die "invalid characters in $v"
done
[[ -n "$PROJECT" ]] || die "--project is required"
[[ -n "$REGION" ]] || die "--region is required"
[[ "$DRZ" == none || "$DRZ" == drz ]] || die "--data-residency must be none or drz"
[[ "$EXPOSURE" == none || "$EXPOSURE" == external ]] || die "--exposure must be none or external"
if [[ "$BILLING" == EVALUATION && "$DRZ" == drz ]]; then die "evaluation orgs do not support data residency"; fi
if ((SHARED)) && [[ -z "$HOST" ]]; then die "this preset needs --host-project (the Shared VPC host)"; fi
if ((!SHARED)) && [[ -n "$HOST" ]]; then die "--host-project only applies to *-shared presets"; fi
if ((PEERED)) && [[ "$EXPOSURE" == external ]]; then die "--exposure external needs a PSC preset (peered orgs are reached over the VPC)"; fi
if [[ "$DRZ" == drz ]]; then
  [[ -n "$CPLOC" && -n "$CDREGION" ]] || die "data residency needs --control-plane-location and --consumer-data-region"
  [[ "$CMEK" == 1 ]] || CMEK=1
else
  [[ -n "$ANALYTICS" ]] || die "--analytics-region is required without data residency"
fi
[[ -n "$INSTANCE" ]] || INSTANCE="instance-$REGION"
NETPROJ="${HOST:-$PROJECT}"
[[ -n "$ENVGROUP" ]] && ENVNAME="$ENVGROUP"

# ---- step list
KIND=() ARG1=() ARG2=() ARG3=()
g() { KIND+=(g); ARG1+=("$*"); ARG2+=(""); ARG3+=(""); }
api() { KIND+=(api); ARG1+=("$1"); ARG2+=("$2"); ARG3+=("${3:-}"); } # METHOD PATH BODY

key() { printf 'projects/%s/locations/%s/keyRings/%s/cryptoKeys/%s' "$PROJECT" "$1" "$2" "$3"; }
mkkey() { # location keyring key
  g kms keyrings create "$2" --location="$1" --project="$PROJECT"
  g kms keys create "$3" --keyring="$2" --location="$1" --purpose=encryption --project="$PROJECT"
  g kms keys add-iam-policy-binding "$3" --keyring="$2" --location="$1" --project="$PROJECT" \
    --member="serviceAccount:service-@PROJNUM@@gcp-sa-apigee.iam.gserviceaccount.com" --role=roles/cloudkms.cryptoKeyEncrypterDecrypter
}

NOTES=()
[[ "$DRZ" == drz ]] && NOTES+=("APIGEE_CONTROL_PLANE_LOCATION=$CPLOC  (regional endpoint apigee.$CPLOC.rep.googleapis.com; the control plane location cannot be changed later)")
[[ "$DRZ" == drz && "$CPLOC" == eu* ]] && NOTES+=("EU data residency can require external (partner-managed) keys; create them first and adjust the key names below")

# 1. APIs
SVCS="apigee.googleapis.com"
if ((PEERED || SHARED)) || [[ "$EXPOSURE" == external ]]; then SVCS="$SVCS compute.googleapis.com"; fi
if ((CMEK)); then SVCS="$SVCS cloudkms.googleapis.com"; fi
if ((PEERED)); then SVCS="$SVCS servicenetworking.googleapis.com"; fi
g services enable $SVCS --project="$PROJECT"
g beta services identity create --service=apigee.googleapis.com --project="$PROJECT"
if ((SHARED)); then
  HOSTSVCS="compute.googleapis.com"
  if ((PEERED)); then HOSTSVCS="$HOSTSVCS servicenetworking.googleapis.com"; fi
  g services enable $HOSTSVCS --project="$HOST"
  g compute shared-vpc enable "$HOST"
  g compute shared-vpc associated-projects add "$PROJECT" --host-project "$HOST"
fi

# 2. keys
if ((CMEK)); then
  mkkey "$REGION" apigee-runtime runtime-db
  if [[ "$DRZ" == drz ]]; then
    mkkey "$CPLOC" apigee-control-plane control-plane
    mkkey "$CDREGION" apigee-consumer-data consumer-data
    mkkey "$REGION" apigee-disk runtime-disk
  fi
fi

# 3. network
if ((PEERED)) || [[ "$EXPOSURE" == external ]]; then
  g compute networks create "$NET" --subnet-mode=custom --project="$NETPROJ"
fi
if ((PEERED)); then
  g compute addresses create apigee-range --global --prefix-length=22 --purpose=VPC_PEERING --network="$NET" --project="$NETPROJ"
  g services vpc-peerings connect --service=servicenetworking.googleapis.com --network="$NET" --ranges=apigee-range --project="$NETPROJ"
fi
SUBNET="apigee-subnet"
if [[ "$EXPOSURE" == external ]]; then
  g compute networks subnets create "$SUBNET" --network="$NET" --region="$REGION" --range=10.10.0.0/24 --project="$NETPROJ"
  SUBNET="projects/$NETPROJ/regions/$REGION/subnetworks/apigee-subnet"
fi

# 4. org
ORG='{"runtimeType":"CLOUD","billingType":"'"$BILLING"'"'
if [[ "$DRZ" == drz ]]; then
  ORG+=',"controlPlaneEncryptionKeyName":"'"$(key "$CPLOC" apigee-control-plane control-plane)"'"'
  ORG+=',"apiConsumerDataLocation":"'"$CDREGION"'"'
  ORG+=',"apiConsumerDataEncryptionKeyName":"'"$(key "$CDREGION" apigee-consumer-data consumer-data)"'"'
else
  ORG+=',"analyticsRegion":"'"$ANALYTICS"'"'
fi
if ((PEERED)); then ORG+=',"authorizedNetwork":"projects/'"$NETPROJ"'/global/networks/'"$NET"'"'; else ORG+=',"disableVpcPeering":true'; fi
((CMEK)) && ORG+=',"runtimeDatabaseEncryptionKeyName":"'"$(key "$REGION" apigee-runtime runtime-db)"'"'
ORG+='}'
api POST "/organizations?parent=projects/$PROJECT" "$ORG"

# 5. instance
INS='{"name":"'"$INSTANCE"'","location":"'"$REGION"'"'
[[ "$DRZ" == drz ]] && INS+=',"diskEncryptionKeyName":"'"$(key "$REGION" apigee-disk runtime-disk)"'"'
((PEERED)) && [[ -n "$IPRANGE" ]] && INS+=',"ipRange":"'"$IPRANGE"'"'
((PEERED)) || INS+=',"consumerAcceptList":["'"$PROJECT"'"]'
INS+='}'
api POST "/organizations/$PROJECT/instances" "$INS"

# 6. environment, envgroup, attachments
api POST "/organizations/$PROJECT/environments" '{"name":"'"$ENVNAME"'"}'
api POST "/organizations/$PROJECT/instances/$INSTANCE/attachments" '{"environment":"'"$ENVNAME"'"}'
if [[ -n "$ENVGROUP" ]]; then
  api POST "/organizations/$PROJECT/envgroups" '{"name":"'"$ENVGROUP"'","hostnames":["'"$ENVGROUP_HOST"'"]}'
  api POST "/organizations/$PROJECT/envgroups/$ENVGROUP/attachments" '{"environment":"'"$ENVNAME"'"}'
fi

# 7. northbound PSC + external load balancer
if [[ "$EXPOSURE" == external ]]; then
  g compute network-endpoint-groups create apigee-psc-neg --network-endpoint-type=private-service-connect \
    --psc-target-service=@SERVICE_ATTACHMENT@ --region="$REGION" --network="$NET" --subnet="$SUBNET" --project="$PROJECT"
  g compute addresses create apigee-lb-ip --global --project="$PROJECT"
  g compute backend-services create apigee-backend --load-balancing-scheme=EXTERNAL_MANAGED --protocol=HTTPS --global --project="$PROJECT"
  g compute backend-services add-backend apigee-backend --network-endpoint-group=apigee-psc-neg --network-endpoint-group-region="$REGION" --global --project="$PROJECT"
  [[ -n "$ENVGROUP_HOST" ]] || die "--exposure external needs --envgroup NAME=HOSTNAME for the certificate"
  g compute ssl-certificates create apigee-cert --domains="$ENVGROUP_HOST" --global --project="$PROJECT"
  g compute url-maps create apigee-urlmap --default-service=apigee-backend --global --project="$PROJECT"
  g compute target-https-proxies create apigee-proxy --url-map=apigee-urlmap --ssl-certificates=apigee-cert --global --project="$PROJECT"
  g compute forwarding-rules create apigee-fr --load-balancing-scheme=EXTERNAL_MANAGED --address=apigee-lb-ip --target-https-proxy=apigee-proxy --ports=443 --global --project="$PROJECT"
fi

# ---- plan
print_plan() {
  local i n note
  for note in ${NOTES[@]+"${NOTES[@]}"}; do printf '# %s\n' "$note"; done
  n=${#KIND[@]}
  for ((i = 0; i < n; i++)); do
    if [[ "${KIND[i]}" == g ]]; then
      printf 'gcloud %s\n' "${ARG1[i]}"
    else
      printf 'apigee raw %s %s --json %s --wait\n' "${ARG1[i]}" "${ARG2[i]}" "'${ARG3[i]}'"
    fi
  done
}

if [[ "$MODE" == plan ]]; then print_plan; exit 0; fi

# ---- apply
if [[ -z "$YES" ]]; then
  if [[ -t 0 ]]; then
    print_plan
    read -r -p "Apply this landing zone to project '$PROJECT'? [y/N] " ans
    [[ "$ans" == y || "$ans" == Y ]] || die "aborted"
  else
    die "apply needs --yes when not run interactively (review with 'plan' first)"
  fi
fi

export APIGEE_PLATFORM=x APIGEE_ORG="$PROJECT"
[[ "$DRZ" == drz ]] && export APIGEE_CONTROL_PLANE_LOCATION="$CPLOC"
PROJNUM="" SA=""
command -v gcloud >/dev/null || die "gcloud is required"
if ((CMEK)); then
  PROJNUM="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)' 2>/dev/null || true)"
  [[ -n "$PROJNUM" ]] || printf 'warning: could not read the project number; KMS IAM bindings may need fixing\n' >&2
fi
n=${#KIND[@]}
for ((i = 0; i < n; i++)); do
  if [[ "${KIND[i]}" == g ]]; then
    line="${ARG1[i]//@PROJNUM@/$PROJNUM}"
    line="${line//@SERVICE_ATTACHMENT@/$SA}"
    read -ra words <<<"$line"
    printf '+ gcloud %s\n' "$line" >&2
    gcloud "${words[@]}"
  else
    printf '+ apigee raw %s %s\n' "${ARG1[i]}" "${ARG2[i]}" >&2
    "$APIGEE" --yes raw "${ARG1[i]}" "${ARG2[i]}" --json "${ARG3[i]}" --wait >/dev/null
    if [[ "${ARG2[i]}" == */instances ]]; then
      SA="$("$APIGEE" raw GET "${ARG2[i]}/$INSTANCE" 2>/dev/null | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("serviceAttachment",""))
except Exception: print("")' || true)"
    fi
  fi
done
printf 'Landing zone applied for %s (%s).\n' "$PROJECT" "$PRESET"
