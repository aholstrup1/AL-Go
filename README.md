# AL-Go for GitHub

AL-Go for GitHub is a set of GitHub templates and actions, which can be used to setup and maintain professional DevOps processes for your Business Central AL projects.

The goal is that people who have created their GitHub repositories based on the AL-Go templates, can maintain these repositories and stay current just by running a workflow, which updates their repositories. This includes necessary changes to scripts and workflows to cope with new features and functions in Business Central.

## Quick Links

- 📍 **Roadmap**: [https://aka.ms/ALGoRoadmap](https://aka.ms/ALGoRoadmap)
- 📝 **Release Notes**: [RELEASENOTES.md](./RELEASENOTES.md)
- ⚠️ **Deprecations**: [DEPRECATIONS.md](./DEPRECATIONS.md)
- 🔧 **Settings Reference**: [Scenarios/settings.md](./Scenarios/settings.md)

## Getting Started

### Choose Your Template

| Template Type | Description | Repository |
| --- | --- | --- |
| **Per Tenant Extension (PTE)** | For developing apps deployed to specific tenants | [AL-Go-PTE](https://github.com/microsoft/AL-Go-PTE) ([aka.ms/algopte](https://aka.ms/algopte)) |
| **AppSource App** | For developing apps distributed through Microsoft AppSource | [AL-Go-AppSource](https://github.com/microsoft/AL-Go-AppSource) ([aka.ms/algoappsource](https://aka.ms/algoappsource)) |

### Learning Resources

**📚 [AL-Go Workshop](https://aka.ms/algoworkshop)** - Complete hands-on workshop covering all AL-Go functionality

**🎯 Quick Start Guide** - [Create your first AL-Go repository](Scenarios/GetStarted.md)

## Documentation

### Common Scenarios

### Setup and Configuration
1. [Create a new per-tenant extension and start developing in VS Code](Scenarios/GetStarted.md)
1. [Set up CI/CD for an existing per tenant extension](Scenarios/SetupCiCdForExistingPTE.md)
1. [Set up CI/CD for an existing AppSource App](Scenarios/SetupCiCdForExistingAppSourceApp.md)
1. [Update AL-Go system files](Scenarios/UpdateAlGoSystemFiles.md)
1. [Use Azure KeyVault for secrets with AL-Go](Scenarios/UseAzureKeyVault.md)

### Development and Testing
1. [Add a test app to an existing project](Scenarios/AddATestApp.md)
1. [Add a performance test app to an existing project](Scenarios/AddAPerformanceTestApp.md)
1. [Set up your own GitHub runner to increase build performance](Scenarios/SelfHostedGitHubRunner.md)
1. [Introducing a dependency to another GitHub repository](Scenarios/AppDependencies.md)

### Environments and Deployment  
1. [Create Online Development Environment from VS Code](Scenarios/CreateOnlineDevEnv.md)
1. [Create Online Development Environment from GitHub](Scenarios/CreateOnlineDevEnv2.md)
1. [Register a customer sandbox environment for Continuous Deployment using S2S](Scenarios/RegisterSandboxEnvironment.md)
1. [Register a customer production environment for Manual Deployment](Scenarios/RegisterProductionEnvironment.md)

### Releases and Publishing
1. [Create a release of your application](Scenarios/CreateRelease.md)
1. [Publish your app to AppSource](Scenarios/PublishToAppSource.md)

### Advanced Topics
1. [Enabling Telemetry for AL-Go workflows and actions](Scenarios/EnablingTelemetry.md)
1. [Enable KeyVault access for your AppSource App during development and/or tests](Scenarios/EnableKeyVaultForAppSourceApp.md)
1. [Connect your GitHub repository to Power Platform](Scenarios/SetupPowerPlatform.md)
1. [How to set up Service Principal for Power Platform](Scenarios/SetupServicePrincipalForPowerPlatform.md)
1. [Try one of the Business Central and Power Platform samples](Scenarios/TryPowerPlatformSamples.md)
1. [Customizing AL-Go for GitHub](Scenarios/CustomizingALGoForGitHub.md)
1. [Create a GhTokenWorkflow secret](Scenarios/GhTokenWorkflow.md)

### Migration Scenarios

A. [Migrate a repository from Azure DevOps to AL-Go for GitHub without history](Scenarios/MigrateFromAzureDevOpsWithoutHistory.md)  
B. [Migrate a repository from Azure DevOps to AL-Go for GitHub with history](Scenarios/MigrateFromAzureDevOpsWithHistory.md)

### Configuration Reference

> [!NOTE]
> For detailed information about settings and configuration options, see the [Settings Reference Guide](Scenarios/settings.md).

## For Contributors

### Project Structure

This project is the main source repository for AL-Go for GitHub. This project is deployed on every release to a branch in the following repositories:

| Repository | Purpose |
| --- | --- |
| [AL-Go-PTE](https://github.com/microsoft/AL-Go-PTE) | Template for Per Tenant Extensions |
| [AL-Go-AppSource](https://github.com/microsoft/AL-Go-AppSource) | Template for AppSource apps |
| [AL-Go-Actions](https://github.com/microsoft/AL-Go-Actions) | GitHub Actions used by the templates |

### Contributing

Please read [this document](Scenarios/Contribute.md) to understand how to contribute to AL-Go for GitHub.

This project welcomes contributions and suggestions. Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit [https://cla.opensource.microsoft.com](https://cla.opensource.microsoft.com).

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

### Additional Resources

- [Developing Extensions in AL](https://go.microsoft.com/fwlink/?linkid=2216858&clcid=0x409)
- [AL-Go for GitHub](https://freddysblog.com/2022/04/26/al-go-for-github/)
- [Migrating to AL-Go for GitHub](https://freddysblog.com/2022/04/27/migrating-to-al-go-for-github/)
- [Structuring your AL-Go for GitHub repositories](https://freddysblog.com/2022/04/28/structuring-your-github-repositories/)
- [Preview of future AL-Go for GitHub functionality](https://freddysblog.com/2022/05/02/al-go-for-github-preview-bits/)
- [Branching strategies for your AL-Go for GitHub repo](https://freddysblog.com/2022/05/03/branching-strategies-for-your-al-go-for-github-repo/)
- [Deployment strategies and AL-Go for GitHub](https://freddysblog.com/2022/05/06/deployment-strategies-and-al-go-for-github/)
- [Secrets in AL-Go for GitHub](https://freddysblog.com/2022/05/14/secrets-in-al-go-for-github/)

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
