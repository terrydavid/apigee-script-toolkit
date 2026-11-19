# apigeecli command groups and their `apigee` equivalents

The toolkit never calls `apigeecli`; it talks to the management API with `curl`.
This table maps each `apigeecli` command group (as of its 1.x docs) to the toolkit.

| apigeecli group | Toolkit | Notes |
|---|---|---|
| `apis`, `sharedflows` | `apigee proxy`, `apigee sharedflow` (list revisions latest deployed stale export download import deploy undeploy delete delete-revision clean-revisions compare) | `apis export` = `proxy export`; `apis fetch` = `proxy download`; `apis trace` = `apigee trace` |
| `apis create` from OpenAPI/GraphQL | not converted | needs an OpenAPI-to-proxy generator; use `apigeecli apis create -f spec.yaml`, then `apigee proxy import` |
| `apps`, `developers`, `products` | `apigee app`, `developer`, `product`, `credential` | |
| `appgroups`, `datacollectors`, `datastores`, `references`, `securityprofiles`, `sites`, `endpoints`, `apicategories`, `apidocs` | `apigee appgroup\|datacollector\|datastore\|reference\|securityprofile\|site\|endpoint\|apicategory\|apidoc` (list get create update delete; apicategory/apidoc need `--site`) | X / hybrid only |
| `operations` | `apigee operation list\|get` | |
| `cache` | `apigee cache` | Edge/OPDK (X caches are runtime-only) |
| `envs` | `apigee env` (list get create delete debugmask health export import) | env `props`/deployment-config not converted; use `apigee raw` |
| `envgroups` | `apigee envgroup` (list get attachments attach) | |
| `flowhooks` | `apigee flowhook` | |
| `iam` | `apigee iam get\|set` | |
| `instances` | `apigee instance` (list attachments attach) | `create`/`delete` instance provisioning not converted: use Terraform or `gcloud` |
| `keyaliases`, `keystores` | `apigee keystore\|truststore` (create delete upload-cert aliases alias-get alias-delete cert csr self-signed) | |
| `kvms` | `apigee kvm` | |
| `orgs` | `apigee org get` | org `create`, `setprops` and `setmask` not converted: provisioning belongs in Terraform; use `apigee raw` for props |
| `preferences` | `apigee profile` | |
| `projects` | not converted | GCP project provisioning; use `gcloud`/Terraform |
| `sync` | `apigee sync get\|add\|remove` | |
| `targetservers` | `apigee target-server` | |
| `token` | `apigee token` | service-account key support: `setup/gcloud-sa-key.sh` |
| anything else | `apigee raw METHOD PATH` | |
