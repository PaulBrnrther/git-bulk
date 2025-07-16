#!/bin/bash

# Parse command line arguments
commit_message_filter=""
repo_list_file=""
repos_directory=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --message-filter)
            commit_message_filter="$2"
            shift 2
            ;;
        *)
            if [ -z "$repo_list_file" ]; then
                repo_list_file="$1"
            elif [ -z "$repos_directory" ]; then
                repos_directory="$1"
            else
                echo "Error: Too many arguments"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$repo_list_file" ] || [ -z "$repos_directory" ]; then
    echo "Usage: $0 [--message-filter <message_start>] <repo_list_file> <repos_directory>"
    echo "  --message-filter: Only revert commits whose message starts with this text"
    echo "  repo_list_file: Path to file containing repository names (one per line)"
    echo "  repos_directory: Path to directory containing the repositories"
    echo ""
    echo "This tool performs a soft reset (git reset --soft HEAD~1) to undo the last commit"
    echo "while keeping the changes staged. Use --message-filter for safety."
    exit 1
fi

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
    
    # Check if there are any commits
    if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
        echo -e "  \033[33mNo commits found, skipping\033[0m"
        echo
        continue
    fi
    
    # Get the last commit message
    last_commit_message=$(git log -1 --pretty=format:"%s")
    
    # Display the last commit info
    echo "  Last commit: $last_commit_message"
    
    # Check if message filter is specified and matches
    if [ -n "$commit_message_filter" ]; then
        if [[ ! "$last_commit_message" == "$commit_message_filter"* ]]; then
            echo -e "  \033[33mCommit message doesn't start with '$commit_message_filter', skipping\033[0m"
            echo
            continue
        fi
        echo -e "  \033[32mCommit message matches filter\033[0m"
    fi
    
    # Check if we have a previous commit to reset to
    if ! git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
        echo -e "  \033[33mThis is the initial commit, cannot revert\033[0m"
        echo
        continue
    fi
    
    # Show what files will be staged after the soft reset
    echo "  Files that will be staged after revert:"
    git diff --name-status HEAD~1 HEAD | while IFS=$'\t' read -r status file; do
        case "$status" in
            A*)
                echo -e "    \033[32mA $file\033[0m"  # Added (green)
                ;;
            M*)
                echo -e "    \033[33mM $file\033[0m"  # Modified (yellow)
                ;;
            D*)
                echo -e "    \033[31mD $file\033[0m"  # Deleted (red)
                ;;
            *)
                echo "    $status $file"
                ;;
        esac
    done
    
    # Perform the soft reset
    if git reset --soft HEAD~1; then
        echo -e "  \033[32mSoft reset successful - changes are now staged\033[0m"
    else
        echo -e "  \033[31mSoft reset failed\033[0m"
    fi
    
    echo
    
done < "$repo_list_file"