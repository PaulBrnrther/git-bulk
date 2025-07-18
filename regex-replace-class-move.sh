#!/bin/bash

# Java Class Renaming Script for Multiple Repositories
# Usage: ./regex-replace-class-move.sh [--no-git] <mapping_file> <repo_list_file> <repos_directory>
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
    echo ""
    echo "Note: repos_directory can be relative or absolute (automatically converted to absolute)"
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

# Convert repos_directory to absolute path
REPOS_DIRECTORY=$(realpath "$REPOS_DIRECTORY")

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

# Function to show progress bar (only at 10% intervals)
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    # Only update display at 10% intervals or at completion
    local prev_percentage=$(( (current - 1) * 100 / total ))
    local prev_ten_percent=$((prev_percentage / 10))
    local curr_ten_percent=$((percentage / 10))
    
    if [ $current -eq 1 ] || [ $current -eq $total ] || [ $curr_ten_percent -gt $prev_ten_percent ]; then
        printf "\r  Progress: ["
        printf "%*s" $filled | tr ' ' '█'
        printf "%*s" $empty | tr ' ' '░'
        printf "] %d%% (%d/%d)" $percentage $current $total
    fi
}

# Convert mapping file to absolute path
MAPPING_FILE=$(realpath "$MAPPING_FILE")

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

# Process each mapping across all repositories at once
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
        
        echo "Processing: $old_fqn -> $new_fqn"
        
        # Find Java files containing references across ALL repositories
        java_files=$(rg -l --type java "$old_fqn|$old_class" "${repo_paths[@]}" 2>/dev/null || true)
        
        if [ -z "$java_files" ]; then
            echo "  No references found in any repository"
            echo
            continue
        fi
        
        # Count total files for progress bar
        total_files=$(echo "$java_files" | wc -l | tr -d ' ')
        current_file=0
        
        echo "  Found references in $total_files files across all repositories"
        
        # Process each file with progress bar
        while IFS= read -r file; do
            [ -f "$file" ] || continue
            
            current_file=$((current_file + 1))
            show_progress $current_file $total_files
            
            # Replace fully qualified name everywhere 
            sed -i "" "s/import ${old_fqn_escaped}\b/import ${new_fqn}/g" "$file"
            sed -i "" "s/\([^a-zA-Z0-9_]\)${old_fqn_escaped}\([^a-zA-Z0-9_]\)/\1${new_fqn}\2/g" "$file"
            
            # If class name changed, replace standalone class name usage
            if [ "$old_class" != "$new_class" ]; then
                sed -i "" "s/\([^a-zA-Z0-9_]\)${old_class}\([^a-zA-Z0-9_]\)/\1${new_class}\2/g" "$file"
            fi
            
        done <<< "$java_files"
        
        # Clear progress bar and show completion
        printf "\r  Progress: [%50s] 100%% (%d/%d) ✓ Complete\n" "$(printf '%*s' 50 | tr ' ' '█')" $total_files $total_files
        
    else
        echo "Warning: Invalid format: $line"
    fi
    
    echo
    
done < "$MAPPING_FILE"
