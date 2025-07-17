#!/bin/bash

# Java Class Renaming Script for Multiple Repositories
# Usage: ./regex-replace-class-move-fast.sh [--no-git] <mapping_file> <repo_list_file> <repos_directory>
# 
# mapping_file format (one per line):
# old.package.ClassName -> new.package.NewClassName
#
# Note: This script replaces class references everywhere in the file, including:
# - Import statements
# - Variable declarations and method signatures  
# - Comments and string literals containing class names
# - Fully qualified names and simple class names

set -e

# Parse command line arguments
NO_GIT_CHECK=false
MAPPING_FILE=""
REPO_LIST_FILE=""
REPOS_DIRECTORY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-git)
            NO_GIT_CHECK=true
            shift
            ;;
        *)
            if [ -z "$MAPPING_FILE" ]; then
                MAPPING_FILE="$1"
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

if [ -z "$MAPPING_FILE" ] || [ -z "$REPO_LIST_FILE" ] || [ -z "$REPOS_DIRECTORY" ]; then
    echo "Usage: $0 [--no-git] <mapping_file> <repo_list_file> <repos_directory>"
    echo "  --no-git: Skip git repository validation"
    echo "  mapping_file: Path to file containing class moves (one per line)"
    echo "  repo_list_file: Path to file containing repository names (one per line)"
    echo "  repos_directory: Path to directory containing the repositories"
    echo ""
    echo "mapping_file format: old.package.ClassName -> new.package.NewClassName"
    exit 1
fi

if [ ! -f "$MAPPING_FILE" ]; then
    echo "Error: Mapping file '$MAPPING_FILE' not found"
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

# Check if required tools are available
for tool in rg sed; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: $tool is not installed"
        exit 1
    fi
done

# Function to escape dots for sed
escape_dots() {
    echo "$1" | sed 's/\./\\./g'
}

# Function to extract class name from FQN
get_class_name() {
    echo "$1" | sed 's/.*\.//'
}

# Convert mapping file to absolute path
MAPPING_FILE=$(realpath "$MAPPING_FILE")

# Process repositories
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
    
    echo "=== $repo_name ==="
    cd "$repo_path" || continue
    
    # Process each mapping for this repository
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Parse mapping: old -> new
        if [[ "$line" =~ ^([^-]+)[[:space:]]*-\>[[:space:]]*(.+)$ ]]; then
            old_fqn=$(echo "${BASH_REMATCH[1]}" | xargs)
            new_fqn=$(echo "${BASH_REMATCH[2]}" | xargs)
            
            old_class=$(get_class_name "$old_fqn")
            new_class=$(get_class_name "$new_fqn")
            
            old_fqn_escaped=$(escape_dots "$old_fqn")
            
            # Find Java files containing references
            java_files=$(rg -l --type java "$old_fqn|$old_class" . 2>/dev/null || true)
            
            if [ -z "$java_files" ]; then
                continue
            fi
            
            echo "  Processing: $old_fqn -> $new_fqn"
            echo "  Found references in $(echo "$java_files" | wc -l) files"
            
            # Process each file
            while IFS= read -r file; do
                [ -f "$file" ] || continue
                
                echo "    Processing: $file"
                
                # Replace fully qualified name everywhere 
                sed -i "" "s/import ${old_fqn_escaped}\b/import ${new_fqn}/g" "$file"
                sed -i "" "s/\([^a-zA-Z0-9_]\)${old_fqn_escaped}\([^a-zA-Z0-9_]\)/\1${new_fqn}\2/g" "$file"
                
                # If class name changed, replace standalone class name usage
                if [ "$old_class" != "$new_class" ]; then
                    sed -i "" "s/\([^a-zA-Z0-9_]\)${old_class}\([^a-zA-Z0-9_]\)/\1${new_class}\2/g" "$file"
                fi
                
                echo "      ✓ Updated"
                
            done <<< "$java_files"
            
        else
            echo "Warning: Invalid format: $line"
        fi
    done < "$MAPPING_FILE"
    
    echo
    
done < "$REPO_LIST_FILE"
