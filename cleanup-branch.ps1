<#
.SYNOPSIS
    Cleans up local git branches that are older than 1 day.

.DESCRIPTION
    This script performs the following actions:
    1. Fetches all remote branches and prunes deleted ones.
    2. Identifies the current branch to avoid deleting it.
    3. Iterates through all local branches.
    4. Checks the last commit date for each branch.
    5. Deletes branches that have not been committed to in more than 1 day.
    6. Excludes 'main' and 'master' branches from deletion.

.NOTES
    This script uses 'git branch -D' which forces deletion. 
    Ensure you have pushed any important changes before running.
#>

# Configuration
$daysThreshold = 0 # WARNING: 0 means delete everything not committed today. Set to 1 for > 24 hours.
$excludedBranches = @("main", "master", "develop", "test", "release", "production")

# 1. Fetch and Prune
Write-Host "Fetching updates and pruning remote tracking branches..." -ForegroundColor Cyan
git fetch --all --prune

# 2. Get Current Branch
$currentBranch = git branch --show-current
if (-not $currentBranch) {
    Write-Host "Error: Could not determine current branch. Are you in a git repository?" -ForegroundColor Red
    exit 1
}
Write-Host "Current branch is: '$currentBranch'" -ForegroundColor Gray

# Add current branch to excluded list
$excludedBranches += $currentBranch

# 3. Calculate Threshold Date
$thresholdDate = (Get-Date).AddDays(-$daysThreshold)
Write-Host "Scanning for branches older than: $($thresholdDate.ToString())" -ForegroundColor Cyan

# 4. Get Branches and Dates
# Using format: branchname|unix_timestamp
$refs = @(git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short)|%(committerdate:unix)')

$branchesToDelete = @()

foreach ($ref in $refs) {
    if ([string]::IsNullOrWhiteSpace($ref)) { continue }

    $parts = $ref -split '\|'
    # Ensure we have at least 2 parts
    if ($parts.Count -lt 2) { continue }
    
    $branchName = $parts[0].Trim()
    $timestamp = [int64]$parts[1].Trim()
    
    # Convert Unix timestamp to DateTime
    $lastCommitDate = [DateTimeOffset]::FromUnixTimeSeconds($timestamp).LocalDateTime

    # Check if branch is excluded
    if ($branchName -in $excludedBranches) {
        Write-Host "Skipping excluded branch: $branchName" -ForegroundColor DarkGray
        continue
    }

    # Check Age
    if ($lastCommitDate -lt $thresholdDate) {
        Write-Host "Found old branch: $branchName (Last commit: $lastCommitDate)" -ForegroundColor Yellow
        $branchesToDelete += $branchName
    }
    else {
        Write-Host "Keeping recent branch: $branchName (Last commit: $lastCommitDate)" -ForegroundColor Green
    }
}

# 5. Delete Branches
if ($branchesToDelete.Count -eq 0) {
    Write-Host "`nNo old branches found to delete." -ForegroundColor Green
}
else {
    Write-Host "`nFound $($branchesToDelete.Count) branches to delete." -ForegroundColor Yellow
    
    foreach ($branch in $branchesToDelete) {
        Write-Host "Deleting branch: $branch" -ForegroundColor Red
        # Check if the branch exists before deleting (safety)
        if (git show-ref --verify --quiet refs/heads/$branch) {
            git branch -D $branch
        }
        else {
            Write-Host "Branch '$branch' not found or already deleted." -ForegroundColor DarkGray
        }
    }
    
    Write-Host "`nCleanup complete." -ForegroundColor Green
}