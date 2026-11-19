# Apigee X landing zones

`setup/landing-zone.sh` builds an Apigee X org from a preset. Always `plan` first, then `apply --yes`.

    setup/landing-zone.sh presets
    setup/landing-zone.sh plan  --preset paid-psc-shared --project P --region us-central1 \
        --host-project HOST --analytics-region us-central1 --exposure external --envgroup prod=api.example.com
    setup/landing-zone.sh apply --yes <same options>

| Preset | Network | Data residency | CMEK |
|---|---|---|---|
| eval-psc | PSC | no (eval orgs cannot) | no |
| paid-peered | VPC peering, own VPC | no | runtime DB |
| paid-peered-shared | VPC peering, Shared VPC host | no | runtime DB |
| paid-psc | PSC (`disableVpcPeering`) | no | runtime DB |
| paid-psc-shared | PSC, subnet in host project | no | runtime DB |
| drz-us-psc | PSC | yes | control plane, consumer data, runtime DB, disk |
| drz-eu-psc-shared | PSC, Shared VPC | yes (EU) | same; EU may need external keys |

Notes
- Peering vs PSC is set on the org (`disableVpcPeering`), which gcloud cannot do, so the script uses the API (`apigee raw ... --wait`).
- Data residency orgs use the regional endpoint; the script exports `APIGEE_CONTROL_PLANE_LOCATION` (the toolkit then calls `apigee.LOCATION.rep.googleapis.com`; override with `APIGEE_X_API_URL`). The control plane location cannot be changed later.
- `--exposure external` builds PSC NEG, backend, managed cert, URL map, HTTPS proxy and forwarding rule. Southbound PSC is not scripted.
- Unverified against a live project: the DRZ endpoint form, `apiConsumerDataEncryptionKeyName`, peering range sizing, Shared VPC IAM prerequisites, EU external-key flow.
