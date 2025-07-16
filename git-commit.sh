#!/bin/bash

# Parse command line arguments
add_hidden_files=false
commit_message=""
repo_list_file=""
repos_directory=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --add-hidden-files)
            add_hidden_files=true
            shift
            ;;
        -m|--message)
            commit_message="$2"
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
    echo "Usage: $0 [--add-hidden-files] [-m|--message <message>] <repo_list_file> <repos_directory>"
    echo "  --add-hidden-files: Include hidden files (files starting with .) in commit"
    echo "  -m, --message: Commit message (if not provided, will prompt for each repo)"
    echo "  repo_list_file: Path to file containing repository names (one per line)"
    echo "  repos_directory: Path to directory containing the repositories"
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
    
    # Get status output to show what will be committed
    status_output=$(git status --porcelain)
    
    if [ -z "$status_output" ]; then
        echo "  Clean working directory - nothing to commit"
        echo
        continue
    fi
    
    # Show current status with colors
    echo "  Files to be committed:"
    hidden_files_present=false
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            status_char="${line:0:2}"
            file_path="${line:3}"
            
            # Check if it's a hidden file
            if [[ "$file_path" == .* ]]; then
                hidden_files_present=true
                if [ "$add_hidden_files" = true ]; then
                    color="\033[32m"  # Green for files that will be committed
                else
                    color="\033[31m"  # Red for files that will be skipped
                fi
            else
                color="\033[32m"  # Green for regular files
            fi
            
            echo -e "    ${color}$status_char $file_path\033[0m"
        fi
    done <<< "$status_output"
    
    if [ "$hidden_files_present" = true ] && [ "$add_hidden_files" = false ]; then
        echo -e "  \033[33mNote: Hidden files shown in red will be skipped. Use --add-hidden-files to include them.\033[0m"
    fi
    
    # Add files to staging area
    if [ "$add_hidden_files" = true ]; then
        git add .
    else
        # Add only non-hidden files
        git add $(git ls-files --others --exclude-standard | grep -v '^\.')
        git add $(git diff --name-only | grep -v '^\.')
        git add $(git diff --cached --name-only | grep -v '^\.')
    fi
    
    # Check if there are staged changes
    staged_changes=$(git diff --cached --name-only)
    if [ -z "$staged_changes" ]; then
        echo "  No files staged for commit"
        echo
        continue
    fi
    
    # Get commit message
    if [ -z "$commit_message" ]; then
        echo -n "  Enter commit message for $repo_name: "
        read -r user_message
        if [ -z "$user_message" ]; then
            echo "  Skipping commit (no message provided)"
            git reset HEAD . > /dev/null 2>&1
            echo
            continue
        fi
        current_message="$user_message"
    else
        current_message="$commit_message"
    fi
    
    # Commit the changes
    if git commit -m "$current_message"; then
        echo -e "  \033[32mCommitted successfully\033[0m"
    else
        echo -e "  \033[31mCommit failed\033[0m"
    fi
    
    echo
    
done < "$repo_list_file"