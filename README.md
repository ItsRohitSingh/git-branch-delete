# Git Remote Branch Cleanup Script

This PowerShell script automates the cleanup of old remote Git branches that have not been modified within a specified number of days.

## Features

- Fetches and prunes remote tracking branches (`git fetch --all --prune`).
- Identifies remote branches older than a configurable threshold (default: 90 days).
- Excludes critical branches (e.g., `main`, `master`, `develop`) from deletion.
- Supports a **Dry Run** mode to preview changes before actual deletion.

## Prerequisites

- Windows with PowerShell.
- Git installed and available in the system PATH.
- Access to the remote repository (authenticated).

## Configuration

You can modify the following variables at the top of the `cleanup-branch.ps1` script:

- **$daysThreshold**: Number of days to keep branches (default: 90).
- **$excludedBranches**: List of branch names to protect from deletion (default: `main`, `master`, `develop`, `test`, `release`, `production`).
- **$remoteName**: Name of the remote repository (default: `origin`).

## Usage

### 1. View Help
The script includes comment-based help. You can view it using:
```powershell
Get-Help .\cleanup-branch.ps1 -Full
```

### 2. Dry Run (Default)
By default, the script runs in **Dry Run** mode. It will list the branches that qualify for deletion without actually deleting them.

#### PowerShell
```powershell
.\cleanup-branch.ps1
# OR
.\cleanup-branch.ps1 -DryRun $true
```

#### Bash (Shell)
```bash
# Make executable first
chmod +x cleanup-branch.sh

./cleanup-branch.sh
# OR
./cleanup-branch.sh --help
```

### 3. Delete Branches
To actually delete the remote branches, use the delete flag.

**⚠️ WARNING: This will permanently delete remote branches!**

#### PowerShell
```powershell
.\cleanup-branch.ps1 -DryRun $false
```

#### Bash (Shell)
```bash
./cleanup-branch.sh --delete
```

## How it Works

1. **Fetch & Prune**: Updates the local knowledge of remote branches.
2. **Scan**: Iterates through all remote refs (`refs/remotes/origin/*`).
3. **Filter**:
   - Ignores excluded branches.
   - Compares the last commit date with the threshold date.
4. **Delete**: If not in Dry Run mode, executes `git push origin --delete <branch_name>` for qualifying branches.

## Automated Cleanup (GitHub Actions)

This repository includes a GitHub Action workflow `.github/workflows/cleanup-branches.yml` that automates the cleanup process.

### Triggers

1.  **Scheduled**: Runs automatically every Sunday at 00:00 UTC (Dry Run enabled by default).
2.  **Manual**: Can be triggered manually from the "Actions" tab.

### How to Run Manually

1.  Go to the **Actions** tab in your GitHub repository.
2.  Select the **Remote Branch Cleanup** workflow.
3.  Click **Run workflow**.
4.  Configure the inputs:
    *   **Dry Run**: Uncheck to perform actual deletion.
    *   **Days Threshold**: Set the age threshold for branches (default: 90).
    *   **Remote Name**: Default is `origin`.

### Permissions

The workflow uses `GITHUB_TOKEN` to authenticate. Ensure your repository settings allow **Read and write permissions** for Workflow permissions (Settings > Actions > General).

