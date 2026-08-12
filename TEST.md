# Testing the Azure Function Software Template

This guide tests the template in four stages:

1. register and open the template in Backstage;
2. render it without publishing a repository;
3. generate a real disposable repository and validate it locally;
4. run the GitHub Actions deployment and call the Azure Function.

The examples assume these sibling directories:

```text
/Users/babken/Development/Projects/Learning/
├── azure-function-software-template/
└── backstage-1.53.1/
```

## Prerequisites

- Node.js 22 for the Backstage 1.53.1 checkout;
- Yarn and the Backstage dependencies installed;
- Terraform 1.8 or newer;
- Python 3;
- a GitHub organization in which a disposable private repository can be created;
- an Azure subscription for the deployment test only.

For the simplest GitHub publishing test, use a classic personal access token with the `repo` and `workflow` scopes. Export it in the shell that starts Backstage:

```bash
export GITHUB_TOKEN='<token>'
```

Do not commit the token to `app-config.yaml`.

## 1. Register the template in Backstage

In the Backstage checkout, add this entry under the existing `catalog.locations` list in `app-config.yaml`:

```yaml
catalog:
  locations:
    - type: file
      target: ../../../azure-function-software-template/template.yaml
      rules:
        - allow: [Template]
```

Do not add a second top-level `catalog` key if one already exists. Append only the location entry.

The template owner is `group:default/platform-engineering`. That group must exist in the Backstage catalog. For a quick local test, either register that group or temporarily use a group already present in the sample catalog, such as `group:default/backstage`.

Confirm that the GitHub integration exists in `app-config.yaml`:

```yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}
```

From the Backstage directory, check the configuration and start the app:

```bash
cd /Users/babken/Development/Projects/Learning/backstage-1.53.1
nvm use 22
export NODE_OPTIONS=--no-node-snapshot
yarn backstage-cli config:check --lax
yarn start
```

Open <http://localhost:3000/create>. Verify that **Azure Function with Terraform** appears. Also open <http://localhost:3000/create/actions> and confirm that these actions are available:

- `fetch:template`
- `publish:github`
- `catalog:register`

## 2. Dry-run the template

Open <http://localhost:3000/create/edit>, choose **Load Template Directory**, and select this repository directory:

```text
/Users/babken/Development/Projects/Learning/azure-function-software-template
```

Use values similar to these:

| Field | Test value |
|---|---|
| Component name | `orders-function` |
| Description | `Backstage Azure Function test` |
| Owner | a group that exists in the catalog |
| Environment | `dev` |
| Azure region | `eastus` |
| Resource group | `rg-orders-function-dev` |
| Function App prefix | `orders-fn` |
| Repository | a disposable repository name in the test organization |

Run the dry-run and inspect the rendered files. The result must contain:

```text
config-generated/dev/globals.yaml
config-generated/dev/functionapps/orders-function.yaml
infra/locals.tf
infra/validations.tf
.github/workflows/deploy.yml
```

Check the following:

- no `terraform.tfvars` file is generated;
- `globals.yaml` contains `environment: dev` and `location: eastus`;
- the Function App YAML contains `name_prefix: orders-fn` and the test resource group;
- the workflow contains `TF_VAR_config_environment: dev`;
- GitHub expressions such as `${{ secrets.AZURE_CLIENT_ID }}` remain expressions in the rendered workflow and are not blank or replaced by Backstage.

## 3. Publish a disposable repository

Open <http://localhost:3000/create>, select the template, enter the same test values, and create a new private repository with a unique name.

The task page should show three successful steps:

1. **Render repository**
2. **Publish to GitHub**
3. **Register in Backstage**

Follow both output links and verify that:

- the private GitHub repository exists and has a protected `main` branch;
- the repository contains the rendered YAML configuration paths shown above;
- the generated `catalog-info.yaml` is registered as a Backstage Component;
- the generated repository contains no unresolved `${{ values.* }}` expressions.

If publishing fails while writing `.github/workflows/deploy.yml`, check that the GitHub token has the `workflow` scope. A `403` during repository creation or branch protection normally means the token or GitHub App lacks permission in the selected organization.

## 4. Validate the generated repository locally

Clone the repository produced by Backstage, then run:

```bash
cd <generated-repository>
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra init -backend=false
TF_VAR_config_environment=dev terraform -chdir=infra validate
python3 -m compileall function_app
```

Expected results:

- the formatting command exits successfully without output;
- provider initialization succeeds;
- Terraform reports `Success! The configuration is valid.`;
- Python compilation completes without a syntax error.

`terraform validate` validates Terraform syntax and provider schemas, but it does not prove every YAML value is correct. Inspect the decoded YAML values with Terraform console:

```bash
TF_VAR_config_environment=dev terraform -chdir=infra console
```

At the Terraform prompt, evaluate:

```hcl
local.selected_environment
local.location
local.function_apps
```

The values should show `dev`, `eastus`, and an `orders-function` entry containing the configured name prefix and resource group. Exit with `Ctrl-D`.

To exercise all YAML checks and resource expressions, run a plan after signing in to Azure:

```bash
az login
az account set --subscription '<subscription-id-or-name>'
export ARM_SUBSCRIPTION_ID='<subscription-id>'
TF_VAR_config_environment=dev terraform -chdir=infra plan -refresh=false
```

This local plan uses no remote backend because initialization used `-backend=false`. Do not apply this local plan if the GitHub workflow will own the deployment and remote state.

### Optional local Function test

With Azure Functions Core Tools 4 installed:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r function_app/requirements.txt
cd function_app
func start
```

In a second terminal:

```bash
curl 'http://localhost:7071/api/hello?name=Babken'
```

Expected response:

```json
{"message": "Hello, Babken!", "service": "orders-function", "status": "ok"}
```

## 5. Configure the generated repository for Azure

Create an Azure Storage account and private blob container for Terraform state. These state resources must already exist and must not be managed by this generated repository.

Create an Entra application or user-assigned managed identity with a federated credential for the generated repository's `main` branch:

```text
repo:<github-owner>/<github-repository>:ref:refs/heads/main
```

If pull requests must run Terraform plans, add a second federated credential with this subject:

```text
repo:<github-owner>/<github-repository>:pull_request
```

Grant the identity:

- `Contributor` at a scope that permits creating the configured resource group and its resources;
- `Storage Blob Data Contributor` on the Terraform state storage account.

Add these GitHub Actions secrets to the generated repository:

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | federated identity client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

Add these GitHub Actions variables:

| Variable | Value |
|---|---|
| `TF_STATE_RESOURCE_GROUP` | resource group containing the state storage account |
| `TF_STATE_STORAGE_ACCOUNT` | state storage account name |
| `TF_STATE_CONTAINER` | private blob container name |

The workflow job is intentionally skipped until all three state variables are non-empty.

## 6. Test the GitHub Actions workflow

First test the non-destructive pull-request path:

1. create a branch in the generated repository;
2. make a harmless change under `config-generated/`, such as adding a tag;
3. open a pull request to `main`;
4. verify that **Deploy Azure Function** runs through Terraform plan;
5. verify that no apply or Function deployment step runs on the pull request.

Then merge the pull request, push a qualifying change to `main`, or run **Deploy Azure Function** with `workflow_dispatch`. On `main`, verify that:

- Azure OIDC login succeeds without a client secret;
- Terraform format, initialization, validation, plan, and apply succeed;
- the Function package is deployed;
- the workflow prints `function_url` in the final step.

## 7. Smoke-test the deployed Function

Use the URL printed by the workflow:

```bash
curl 'https://<generated-function-app-name>.azurewebsites.net/api/hello?name=Babken'
```

Expected response:

```json
{"message": "Hello, Babken!", "service": "orders-function", "status": "ok"}
```

The first request immediately after deployment can be slower while the Consumption Function App starts.

## Acceptance checklist

- [ ] Backstage loads the Template entity without catalog errors.
- [ ] The three required scaffolder actions are installed.
- [ ] The dry-run generates YAML configuration and no `.tfvars` file.
- [ ] GitHub expressions survive Backstage rendering.
- [ ] Backstage creates and registers a disposable private repository.
- [ ] Terraform formatting, initialization, validation, and YAML inspection pass.
- [ ] Python compilation or the optional local Function test passes.
- [ ] The pull-request workflow plans without applying.
- [ ] The `main` workflow provisions Azure and deploys the Function.
- [ ] The deployed `/api/hello` endpoint returns HTTP 200 and the expected JSON.

After the test, destroy only the disposable Azure resources and delete the disposable repository when they are no longer needed. Do not delete a shared Terraform state storage account or container.
