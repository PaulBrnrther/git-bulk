#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <repo_list_file> <repos_directory>"
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
    
    # Get porcelain status output
    status_output=$(git status --porcelain)
    
    if [ -z "$status_output" ]; then
        echo "  Clean working directory"
    else
        # Process each line and add colors
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                status_char="${line:0:2}"
                file_path="${line:3}"
                
                case "$status_char" in
                    "A "* | "??"*)
                        # New files (green)
                        echo -e "  \033[32m$status_char $file_path\033[0m"
                        ;;
                    "M "* | " M"* | "MM"* | "R "* | " R"* | "RR"*)
                        # Modified/moved files (orange)
                        echo -e "  \033[33m$status_char $file_path\033[0m"
                        ;;
                    "D "* | " D"* | "DD"*)
                        # Deleted files (red)
                        echo -e "  \033[31m$status_char $file_path\033[0m"
                        ;;
                    *)
                        # Other status (default)
                        echo "  $status_char $file_path"
                        ;;
                esac
            fi
        done <<< "$status_output"
    fi
    
    echo
    
done < "$repo_list_file"