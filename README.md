# Power BI DevOps

A set of tools aimed to make managing Power BI artifacts and deployments easier.

## Overview

The basic workflow allows

### Export Pipeline

1. Exports datasets as `.bim` files (json/TMSL)
1. Exports reports (all report items with do not include `dataset` in the name) as `.pbix` files (binary)
1. Extracts the pbix contents (json + xml)
1. Commits the exported/extracted source code to git

### Deploy Pipeline

1. The report deployment pipeline is queued in Azure DevOps
1. The Tabular Model Scripting Language (TMSL) dataset file is deployed via the XMLA endpoints
1. The extracted report source code is compiled into a pbix
1. The pbix file is uploaded to the target environment
1. The report is rebound to the dataset and the datasource credentials are updated

## How does it work?

There are 2 major pieces:

1. `agents` - Pipeline agent configuration - these scripts create agent VMs, then install and configure the tools required to work with the pbix files (Power BI Desktop + pbi-tools)
1. `ci-cd` - Extract and compile - these scripts extract and compile the pbix to and from source

## Setup and Usage

You can use these tools in 2 ways:

1. Any Windows pipeline agent - the export/import process can be performed on Windows agent which has chocolatey installed. In this case, Power BI Desktop is installed for every pipeline run and can take 5+ minutes depending on the agent.
1. Specific Windows pipeline agents - you can preconfigure agents with Power BI Desktop and pbi-tools which saves time on each run.

### Prerequisites

#### For Agent Configuration

1. Azure RM Service Connection
1. Variable Group + PAT (currently hardcoded to `group: AgentPoolAdmin` and `$(PAT)`)

#### For CI/CD

1. Variable Group `group: PowerBI`
    - `$(TenantId)`
    - `$(ClientId)`
    - `$(ClientSecret)`

## Other Resources

- https://github.com/microsoft/powerbi-desktop-samples/tree/main/Sample%20Reports
- https://powerbi.microsoft.com/en-us/blog/use-power-bi-api-with-service-principal-preview/
- https://docs.microsoft.com/en-us/powershell/power-bi/overview?view=powerbi-ps