# Keeping your AL-Go Repository Up-to-date

AL-Go for GitHub is continuously updated with new features, bug fixes, and improvements. To ensure your repository benefits from these updates, you should regularly update your AL-Go system files.

## Update AL-Go System Files Workflow

AL-Go provides a built-in workflow to update your repository with the latest AL-Go system files:

1. **Navigate to Actions** in your GitHub repository
2. **Select "Update AL-Go System Files"** workflow
3. **Click "Run workflow"** to start the update process
4. **Review the pull request** that gets created with the updates
5. **Merge the pull request** after reviewing the changes

## What Gets Updated

The Update AL-Go System Files workflow updates:
- GitHub Actions workflows (`.github/workflows/`)
- PowerShell scripts (`.github/scripts/`)
- AL-Go system actions
- Templates and configuration files

## Best Practices

- **Review changes carefully** before merging update pull requests
- **Test your workflows** after updating to ensure everything works correctly  
- **Keep customizations** in supported locations to avoid conflicts
- **Update regularly** to get the latest features and security fixes

## Related Topics

- [Customizing AL-Go for GitHub](../Scenarios/CustomizingALGoForGitHub.md) - How to customize while maintaining updatability
- [Update AL-Go system files](../Scenarios/UpdateAlGoSystemFiles.md) - Detailed update instructions

______________________________________________________________________

[Index](Index.md)  [next](Index.md)