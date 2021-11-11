# Power BI DevOps

A set of tools aimed to make managing Power BI artifacts and deployments easier.

## Overview

The basic workflow allows

### Export

1. Report author saves the report to SharePoint
1. Power Automate flow triggers and runs an Azure DevOps pipeline, passing the report (pbix) url as a parameter
1. Azure DevOps downloads the file, extracts the pbix and commits the extracted source code to git

### Build/Deploy

1. The report deployment pipeline is queued in Azure DevOps
1. The extracted report source code is compiled into a pbix
1. The pbix file is uploaded to the target environment

## How does it work?

There are 2 major pieces:

1. `agents` - Pipeline agent configuration - these scripts create agent VMs, then install and configure the tools required to work with the pbix files (Power BI Desktop + pbi-tools)
1. `ci-cd` - Extract and compile - these scripts extract and compile the pbix to and from source

## Setup and Usage

### Prerequisites

1. Azure RM Service Connection
1. Variable Group + PAT (currently hardcoded to `group: AgentPoolAdmin` and `$(PAT)`)
1. SharePoint app-only access (https://docs.microsoft.com/en-us/sharepoint/dev/solution-guidance/security-apponly-azuread)