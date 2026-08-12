# Azure Function Backstage Software Template

This Backstage template creates a private GitHub repository containing:

- a dummy Python HTTP-triggered Azure Function;
- Terraform for the resource group, storage account, Linux Consumption plan, and Function App;
- YAML-driven environment and Function App configuration under `config-generated/`;
- a GitHub Actions workflow using Azure workload identity federation (OIDC);
- a Backstage `Component` entity registered in the software catalog.

## Add the template to Backstage

1. Commit this directory to the repository that holds your Backstage templates.
2. Register `template.yaml` as a catalog location in Backstage.
3. Confirm that the Backstage backend has the GitHub scaffolder module and a GitHub integration with permission to create repositories.

Set `spec.owner` to your platform team. To restrict repository creation to your organization, add it under `allowedOwners` in the `RepoUrlPicker` options.

The generated repository README contains the Azure identity, Terraform state, and GitHub repository configuration required before its first workflow run.
