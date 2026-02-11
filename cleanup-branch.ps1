<#
.SYNOPSIS
    Cleans up REMOTE git branches that are older than a specific threshold.

.DESCRIPTION
    This script performs the following actions:
    1. Fetches all remote branches and prunes deleted ones.
    2. Iterates through all REMOTE branches (e.g., origin/feature-x).
    3. Checks the last commit date for each branch.
    4. Deletes remote branches that have not been committed to in more than $daysThreshold days.
    5. Excludes 'main', 'master', and HEAD references.

.EXAMPLE
    .\cleanup-branch.ps1 -DryRun $true
    .\cleanup-branch.ps1 -DryRun $false
#>

param (
    [bool]$DryRun = $true
)

# Configuration
$daysThreshold = 90 # in days, if branch is older than this, it will be deleted. Set 0 to delete all branches except those commited today.
$excludedBranches = @("main", "master", "develop", "test", "release", "production", "HEAD", "origin") # Branches to exclude from deletion.
$remoteName = "origin" # Remote name.

Write-Host "--------------------------------------------------" -ForegroundColor Cyan
Write-Host "REMOTE BRANCH CLEANUP SCRIPT" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "Dry Run Mode: $DryRun" -ForegroundColor Yellow
}
else {
    Write-Host "Dry Run Mode: $DryRun" -ForegroundColor Red
}
Write-Host "Threshold: Older than $daysThreshold days" -ForegroundColor Gray
Write-Host "--------------------------------------------------" -ForegroundColor Cyan

# 1. Fetch and Prune
Write-Host "Fetching updates and pruning remote tracking branches..." -ForegroundColor Cyan
git fetch --all --prune

# 2. Calculate Threshold Date
$thresholdDate = (Get-Date).AddDays(-$daysThreshold)
Write-Host "Scanning for remote branches older than: $($thresholdDate.ToString())" -ForegroundColor Cyan

# 3. Get Remote Branches and Dates
# Using format: refname|unix_timestamp
$refs = @(git for-each-ref --sort=-committerdate "refs/remotes/$remoteName/" --format='%(refname:short)|%(committerdate:unix)')

$branchesToDelete = @()

foreach ($ref in $refs) {
    if ([string]::IsNullOrWhiteSpace($ref)) { continue }

    $parts = $ref -split '\|'
    if ($parts.Count -lt 2) { continue }
    
    # $fullBranchName will be like "origin/feature-x"
    $fullBranchName = $parts[0].Trim()
    $timestamp = [int64]$parts[1].Trim()
    
    # Strip the remote prefix to get the actual branch name "feature-x"
    # This is needed for the delete command: git push origin --delete feature-x
    $branchName = $fullBranchName -replace "^$remoteName/", ""

    # Convert Unix timestamp to DateTime
    $lastCommitDate = [DateTimeOffset]::FromUnixTimeSeconds($timestamp).LocalDateTime

    # Check if branch is excluded
    if ($branchName -in $excludedBranches) {
        Write-Host "Skipping excluded branch: $fullBranchName" -ForegroundColor DarkGray
        continue
    }

    # Check Age
    if ($lastCommitDate -lt $thresholdDate) {
        Write-Host "Found old branch: $fullBranchName (Last commit: $lastCommitDate)" -ForegroundColor Yellow
        $branchesToDelete += $branchName
    }
    else {
        Write-Host "Keeping recent branch: $fullBranchName (Last commit: $lastCommitDate)" -ForegroundColor Green
    }
}

# 4. Delete Branches
if ($branchesToDelete.Count -eq 0) {
    Write-Host "`nNo old remote branches found to delete." -ForegroundColor Green
}
else {
    Write-Host "`nFound $($branchesToDelete.Count) remote branches to delete." -ForegroundColor Yellow
    
    foreach ($branch in $branchesToDelete) {
        if ($DryRun) {
            Write-Host "[DRY RUN] Would delete remote branch: $remoteName/$branch" -ForegroundColor Magenta
        }
        else {
            Write-Host "Deleting remote branch: $remoteName/$branch" -ForegroundColor Red
            # Delete from remote
            git push $remoteName --delete $branch
            if ($?) {
                Write-Host "Successfully deleted $remoteName/$branch" -ForegroundColor Green
            }
            else {
                Write-Host "Failed to delete $remoteName/$branch" -ForegroundColor Red
            }
        }
    }
    
    if ($DryRun) {
        Write-Host "`nDry Run complete. No changes were made." -ForegroundColor Yellow
        Write-Host "Run with '-DryRun `$false' to actually delete branches." -ForegroundColor Yellow
    }
    else {
        Write-Host "`nCleanup complete." -ForegroundColor Green
    }
}