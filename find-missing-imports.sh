#!/bin/bash

# Find Missing Imports Script for Multiple Repositories
# Usage: ./find-missing-imports.sh [--no-git] <classes_file> <repo_list_file> <repos_directory>
# 
# classes_file format (one per line):
# full.package.ClassName
#
# This script finds Java files that use class names but are missing the corresponding import statements.

set -e

# Parse command line arguments
NO_GIT_CHECK=false
CLASSES_FILE=""
REPO_LIST_FILE=""
REPOS_DIRECTORY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-git)
            NO_GIT_CHECK=true
            shift
            ;;
        *)
            if [ -z "$CLASSES_FILE" ]; then
                CLASSES_FILE="$1"
            elif [ -z "$REPO_LIST_FILE" ]; then
                REPO_LIST_FILE="$1"
            elif [ -z "$REPOS_DIRECTORY" ]; then
                REPOS_DIRECTORY="$1"
            else
                echo "Error: Too many arguments"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$CLASSES_FILE" ] || [ -z "$REPO_LIST_FILE" ] || [ -z "$REPOS_DIRECTORY" ]; then
    echo "Usage: $0 [--no-git] <classes_file> <repo_list_file> <repos_directory>"
    echo "  --no-git: Skip git repository validation"
    echo "  classes_file: Path to file containing class FQNs (one per line)"
    echo "  repo_list_file: Path to file containing repository names (one per line)"
    echo "  repos_directory: Path to directory containing the repositories"
    echo ""
    echo "classes_file format: full.package.ClassName"
    echo ""
    echo "Note: repos_directory can be relative or absolute (automatically converted to absolute)"
    exit 1
fi

if [ ! -f "$CLASSES_FILE" ]; then
    echo "Error: Classes file '$CLASSES_FILE' not found"
    exit 1
fi

if [ ! -f "$REPO_LIST_FILE" ]; then
    echo "Error: Repository list file '$REPO_LIST_FILE' not found"
    exit 1
fi

if [ ! -d "$REPOS_DIRECTORY" ]; then
    echo "Error: Repositories directory '$REPOS_DIRECTORY' not found"
    exit 1
fi

# Convert repos_directory to absolute path
REPOS_DIRECTORY=$(realpath "$REPOS_DIRECTORY")

# Check if required tools are available
for tool in rg grep; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: $tool is not installed"
        exit 1
    fi
done

# Function to extract class name from FQN
get_class_name() {
    echo "$1" | sed 's/.*\.//'
}

# Function to escape dots for grep
escape_dots() {
    echo "$1" | sed 's/\./\\./g'
}

# Convert classes file to absolute path
CLASSES_FILE=$(realpath "$CLASSES_FILE")

# Build array of valid repository paths
repo_paths=()
while IFS= read -r repo_name; do
    # Skip empty lines and comments
    if [[ -z "$repo_name" || "$repo_name" =~ ^# ]]; then
        continue
    fi
    
    repo_path="$REPOS_DIRECTORY/$repo_name"
    
    if [ ! -d "$repo_path" ]; then
        echo "Warning: Repository '$repo_name' not found at $repo_path"
        continue
    fi
    
    if [ "$NO_GIT_CHECK" = false ] && [ ! -d "$repo_path/.git" ]; then
        echo "Warning: '$repo_name' is not a git repository"
        continue
    fi
    
    repo_paths+=("$repo_path")
done < "$REPO_LIST_FILE"

if [ ${#repo_paths[@]} -eq 0 ]; then
    echo "Error: No valid repositories found"
    exit 1
fi

echo "Found ${#repo_paths[@]} valid repositories"
echo

# Process each class FQN
while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    # Extract class name from FQN
    class_fqn=$(echo "$line" | xargs)
    class_name=$(get_class_name "$class_fqn")
    
    if [ -z "$class_name" ]; then
        echo "Warning: Invalid class FQN: $line"
        continue
    fi
    
    echo "=== Checking for missing import: $class_fqn ==="
    
    # Find Java files that contain the class name but don't have the import
    found_files=false
    
    for repo_path in "${repo_paths[@]}"; do
        repo_name=$(basename "$repo_path")
        
        # Find Java files containing the class name
        java_files=$(rg -l --type java "\b$class_name\b" "$repo_path" 2>/dev/null || true)
        
        if [ -z "$java_files" ]; then
            continue
        fi
        
        # Check each file to see if it's missing the import
        while IFS= read -r file; do
            [ -f "$file" ] || continue
            
            # Check if file contains the class name
            if grep -q "\b$class_name\b" "$file"; then
                # Check if file has the import statement
                fqn_escaped=$(escape_dots "$class_fqn")
                if ! grep -q "^import.*$fqn_escaped" "$file"; then
                    # Also check if it's not using a wildcard import that would cover this class
                    package_path=$(echo "$class_fqn" | sed 's/\.[^.]*$//')
                    package_escaped=$(escape_dots "$package_path")
                    if ! grep -q "^import.*${package_escaped}\.\*" "$file"; then
                        # Get relative path from repo root
                        rel_path=${file#$repo_path/}
                        echo "  $repo_name: $rel_path"
                        found_files=true
                    fi
                fi
            fi
        done <<< "$java_files"
    done
    
    if [ "$found_files" = false ]; then
        echo "  No files found with missing import for $class_name"
    fi
    
    echo
    
done < "$CLASSES_FILE"

echo "Scan complete."