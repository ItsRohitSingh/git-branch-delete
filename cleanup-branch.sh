#!/bin/bash

# Default values
DRY_RUN=true
DAYS_THRESHOLD=90
REMOTE_NAME="origin"
EXCLUDED_BRANCHES=("main" "master" "develop" "test" "release" "production" "HEAD" "origin")

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --delete) DRY_RUN=false ;;
        --threshold) DAYS_THRESHOLD="$2"; shift ;;
        --remote) REMOTE_NAME="$2"; shift ;;
        --help) 
            echo "Usage: ./cleanup-branch.sh [OPTIONS]"
            echo "Options:"
            echo "  --delete      Execute deletion (disable dry-run)"
            echo "  --threshold   Days threshold (default: 90)"
            echo "  --remote      Remote name (default: origin)"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

echo "--------------------------------------------------"
echo "REMOTE BRANCH CLEANUP SCRIPT"
if [ "$DRY_RUN" = true ]; then
    echo -e "\033[33mDry Run Mode: $DRY_RUN\033[0m"
else
    echo -e "\033[31mDry Run Mode: $DRY_RUN\033[0m"
fi
echo "Threshold: Older than $DAYS_THRESHOLD days"
echo "--------------------------------------------------"

# 1. Fetch and Prune
echo "Fetching updates and pruning remote tracking branches..."
git fetch --all --prune

# 2. Calculate Threshold Date (Unix timestamp)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # MacOS date command
    THRESHOLD_DATE=$(date -v-${DAYS_THRESHOLD}d +%s)
else
    # GNU date command (Linux/Git Bash)
    THRESHOLD_DATE=$(date -d "${DAYS_THRESHOLD} days ago" +%s)
fi

echo "Scanning for remote branches older than: $(date -d @$THRESHOLD_DATE)"

# 3. Get Remote Branches and Dates
# format: refname|unix_timestamp
REFS=$(git for-each-ref --sort=-committerdate "refs/remotes/$REMOTE_NAME/" --format='%(refname:short)|%(committerdate:unix)')

BRANCHES_TO_DELETE=()

# Read refs line by line
while IFS='|' read -r FULL_BRANCH_NAME TIMESTAMP; do
    if [ -z "$FULL_BRANCH_NAME" ]; then continue; fi
    
    # Strip remote prefix
    BRANCH_NAME=${FULL_BRANCH_NAME#$REMOTE_NAME/}
    
    # Check if excluded
    IS_EXCLUDED=false
    for EXCLUDED in "${EXCLUDED_BRANCHES[@]}"; do
        if [ "$BRANCH_NAME" == "$EXCLUDED" ] || [ "$FULL_BRANCH_NAME" == "$EXCLUDED" ]; then
            IS_EXCLUDED=true
            break
        fi
    done
    
    if [ "$IS_EXCLUDED" = true ]; then
        echo -e "\033[90mSkipping excluded branch: $FULL_BRANCH_NAME\033[0m"
        continue
    fi
    
    # Check age
    if [ "$TIMESTAMP" -lt "$THRESHOLD_DATE" ]; then
        COMMIT_DATE=$(date -d @$TIMESTAMP 2>/dev/null || date -r $TIMESTAMP 2>/dev/null) # Attempt both GNU and BSD date
        echo -e "\033[33mFound old branch: $FULL_BRANCH_NAME (Last commit: $COMMIT_DATE)\033[0m"
        BRANCHES_TO_DELETE+=("$BRANCH_NAME")
    else
        COMMIT_DATE=$(date -d @$TIMESTAMP 2>/dev/null || date -r $TIMESTAMP 2>/dev/null)
        echo -e "\033[32mKeeping recent branch: $FULL_BRANCH_NAME (Last commit: $COMMIT_DATE)\033[0m"
    fi
    
done <<< "$REFS"

# 4. Delete Branches
if [ ${#BRANCHES_TO_DELETE[@]} -eq 0 ]; then
    echo -e "\n\033[32mNo old remote branches found to delete.\033[0m"
else
    echo -e "\n\033[33mFound ${#BRANCHES_TO_DELETE[@]} remote branches to delete.\033[0m"
    
    for BRANCH in "${BRANCHES_TO_DELETE[@]}"; do
        if [ "$DRY_RUN" = true ]; then
            echo -e "\033[35m[DRY RUN] Would delete remote branch: $REMOTE_NAME/$BRANCH\033[0m"
        else
            echo -e "\033[31mDeleting remote branch: $REMOTE_NAME/$BRANCH\033[0m"
            git push "$REMOTE_NAME" --delete "$BRANCH"
            if [ $? -eq 0 ]; then
                echo -e "\033[32mSuccessfully deleted $REMOTE_NAME/$BRANCH\033[0m"
            else
                echo -e "\033[31mFailed to delete $REMOTE_NAME/$BRANCH\033[0m"
            fi
        fi
    done
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "\n\033[33mDry Run complete. No changes were made.\033[0m"
        echo -e "\033[33mRun with '--delete' to actually delete branches.\033[0m"
    else
         echo -e "\n\033[32mCleanup complete.\033[0m"
    fi
fi
