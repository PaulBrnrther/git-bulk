#!/bin/bash

# Parse command line arguments
force_push=false
set_upstream=false
branch=""
repo_list_file=""
repos_directory=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            force_push=true
            shift
            ;;
        --set-upstream)
            set_upstream=true
            shift
            ;;
        --branch)
            branch="$2"
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
    echo "Usage: $0 [--force] [--set-upstream] [--branch <branch>] <repo_list_file> <repos_directory>"
    echo "  --force: Force push (use with caution)"
    echo "  --set-upstream: Set upstream tracking for the current branch"
    echo "  --branch: Push specific branch (default: current branch)"
    echo "  repo_list_file: Path to file containing repository names (one per line)"
    echo "  repos_directory: Path to directory containing the repositories"
    echo ""
    echo "This tool pushes changes to the remote repository. By default, it's safe and"
    echo "will not force push unless --force is explicitly specified."
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
    
    # Determine which branch to push
    if [ -n "$branch" ]; then
        current_branch="$branch"
        # Check if the specified branch exists
        if ! git rev-parse --verify "$current_branch" >/dev/null 2>&1; then
            echo -e "  \033[31mBranch '$current_branch' does not exist, skipping\033[0m"
            echo
            continue
        fi
    else
        # Get current branch name
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        if [ "$current_branch" = "HEAD" ]; then
            echo -e "  \033[33mDetached HEAD state, skipping\033[0m"
            echo
            continue
        fi
    fi
    
    echo "  Branch: $current_branch"
    
    # Check if there are any commits
    if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
        echo -e "  \033[33mNo commits found, skipping\033[0m"
        echo
        continue
    fi
    
    # Check if remote exists
    remote_url=$(git config --get remote.origin.url 2>/dev/null)
    if [ -z "$remote_url" ]; then
        echo -e "  \033[33mNo remote 'origin' configured, skipping\033[0m"
        echo
        continue
    fi
    
    # Check if there are unpushed commits
    if git ls-remote --exit-code --heads origin "$current_branch" >/dev/null 2>&1; then
        # Remote branch exists, check for differences
        ahead_behind=$(git rev-list --left-right --count origin/"$current_branch"..."$current_branch" 2>/dev/null)
        if [ $? -eq 0 ]; then
            behind=$(echo "$ahead_behind" | cut -f1)
            ahead=$(echo "$ahead_behind" | cut -f2)
            
            if [ "$ahead" -eq 0 ]; then
                echo -e "  \033[32mAlready up to date\033[0m"
                echo
                continue
            fi
            
            if [ "$behind" -gt 0 ]; then
                echo -e "  \033[33mLocal branch is $behind commits behind origin/$current_branch\033[0m"
                if [ "$force_push" = false ]; then
                    echo -e "  \033[31mUse --force to force push (not recommended)\033[0m"
                    echo
                    continue
                else
                    echo -e "  \033[33mForce pushing anyway...\033[0m"
                fi
            fi
            
            echo -e "  \033[32m$ahead commit(s) to push\033[0m"
        fi
    else
        # Remote branch doesn't exist
        echo -e "  \033[32mNew branch - will create on remote\033[0m"
        set_upstream=true
    fi
    
    # Build push command
    push_cmd="git push"
    
    if [ "$set_upstream" = true ]; then
        push_cmd="$push_cmd -u origin $current_branch"
    else
        push_cmd="$push_cmd origin $current_branch"
    fi
    
    if [ "$force_push" = true ]; then
        push_cmd="$push_cmd --force"
    fi
    
    # Execute the push
    echo "  Executing: $push_cmd"
    if eval "$push_cmd"; then
        echo -e "  \033[32mPush successful\033[0m"
    else
        echo -e "  \033[31mPush failed\033[0m"
    fi
    
    echo
    
done < "$repo_list_file"