#!/bin/bash

# Parse arguments
skip_fetch=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-fetch)
            skip_fetch=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -ne 2 ]; then
    echo "Usage: $0 [--no-fetch] <repo_list_file> <repos_directory>"
    echo "  --no-fetch: Skip fetching from remote (default: fetch before reset)"
    echo "  repo_list_file: Path to file containing repository names (one per line)"
    echo "  repos_directory: Path to directory containing the repositories"
    exit 1
fi

repo_list_file="$1"
repos_directory="$2"

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
    
    # Fetch from remote unless --no-fetch is specified
    if [ "$skip_fetch" = false ]; then
        if git fetch origin >/dev/null 2>&1; then
            echo -e "  \033[36mFetched from origin\033[0m"
        else
            echo -e "  \033[31mFailed to fetch from origin\033[0m"
        fi
    fi
    
    # Check if origin/master exists
    if ! git rev-parse --verify origin/master >/dev/null 2>&1; then
        echo -e "  \033[31mWarning: origin/master not found, skipping\033[0m"
        echo
        continue
    fi
    
    # Get current branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    
    # Reset current branch to origin/master
    if git reset --hard origin/master >/dev/null 2>&1; then
        echo -e "  \033[32mReset $current_branch to origin/master\033[0m"
    else
        echo -e "  \033[31mFailed to reset $current_branch to origin/master\033[0m"
    fi
    
    echo
    
done < "$repo_list_file"