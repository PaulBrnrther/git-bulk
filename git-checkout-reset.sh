#!/bin/bash

# Parse command line arguments
no_stash=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-stash)
            no_stash=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -ne 3 ]; then
    echo "Usage: $0 [--no-stash] <repo_list_file> <repos_directory> <branch_name>"
    echo "  --no-stash: Discard pending changes instead of stashing them"
    echo "  repo_list_file: Path to file containing repository names (one per line)"
    echo "  repos_directory: Path to directory containing the repositories"
    echo "  branch_name: Name of the branch to checkout"
    exit 1
fi

repo_list_file="$1"
repos_directory="$2"
branch_name="$3"

if [ ! -f "$repo_list_file" ]; then
    echo "Error: Repository list file '$repo_list_file' not found"
    exit 1
fi

if [ ! -d "$repos_directory" ]; then
    echo "Error: Repositories directory '$repos_directory' not found"
    exit 1
fi

while IFS= read -r repo_name; do
    # Skip empty lines and comments
    if [[ -z "$repo_name" || "$repo_name" =~ ^# ]]; then
        continue
    fi
    
    repo_path="$repos_directory/$repo_name"
    
    if [ ! -d "$repo_path" ]; then
        echo "Warning: Repository '$repo_name' not found at $repo_path"
        continue
    fi
    
    if [ ! -d "$repo_path/.git" ]; then
        echo "Warning: '$repo_name' is not a git repository"
        continue
    fi
    
    echo "=== $repo_name ==="
    cd "$repo_path" || continue
    
    # Fetch all remote branches
    echo "  Fetching..."
    if git fetch --all > /dev/null 2>&1; then
        echo -e "  \033[32m✓ Fetch successful\033[0m"
    else
        echo -e "  \033[31m✗ Fetch failed\033[0m"
        echo
        continue
    fi
    
    # Check for pending changes before checkout
    status_output=$(git status --porcelain)
    if [ -n "$status_output" ]; then
        echo "  Pending changes found:"
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                status_char="${line:0:2}"
                file_path="${line:3}"
                
                case "$status_char" in
                    "A "* | "??"*)
                        echo -e "    \033[32m$status_char $file_path\033[0m"
                        ;;
                    "M "* | " M"* | "MM"* | "R "* | " R"* | "RR"*)
                        echo -e "    \033[33m$status_char $file_path\033[0m"
                        ;;
                    "D "* | " D"* | "DD"*)
                        echo -e "    \033[31m$status_char $file_path\033[0m"
                        ;;
                    *)
                        echo "    $status_char $file_path"
                        ;;
                esac
            fi
        done <<< "$status_output"
        
        if [ "$no_stash" = true ]; then
            echo "  Discarding changes..."
            git reset --hard HEAD > /dev/null 2>&1
            git clean -fd > /dev/null 2>&1
            echo -e "  \033[33m⚠ Changes discarded\033[0m"
        else
            echo "  Stashing changes..."
            if git stash push -m "Auto-stash before checkout to $branch_name" > /dev/null 2>&1; then
                echo -e "  \033[32m✓ Changes stashed\033[0m"
            else
                echo -e "  \033[31m✗ Stash failed\033[0m"
                echo
                continue
            fi
        fi
    fi
    
    # Hard reset and checkout branch
    echo "  Checking out '$branch_name'..."
    if git checkout "$branch_name" > /dev/null 2>&1; then
        echo -e "  \033[32m✓ Checkout successful\033[0m"
        
        # Hard reset to remote branch if it exists
        if git rev-parse --verify "origin/$branch_name" > /dev/null 2>&1; then
            echo "  Hard resetting to origin/$branch_name..."
            if git reset --hard "origin/$branch_name" > /dev/null 2>&1; then
                echo -e "  \033[32m✓ Hard reset successful\033[0m"
            else
                echo -e "  \033[31m✗ Hard reset failed\033[0m"
            fi
        else
            echo -e "  \033[33m⚠ Remote branch 'origin/$branch_name' not found, staying on local branch\033[0m"
        fi
    else
        echo -e "  \033[31m✗ Checkout failed - branch '$branch_name' may not exist\033[0m"
    fi
    
    echo
    
done < "$repo_list_file"