#!/bin/bash

# Parse command line arguments
class_moves_file=""
repo_list_file=""
repos_directory=""

while [[ $# -gt 0 ]]; do
    if [ -z "$class_moves_file" ]; then
        class_moves_file="$1"
    elif [ -z "$repo_list_file" ]; then
        repo_list_file="$1"
    elif [ -z "$repos_directory" ]; then
        repos_directory="$1"
    else
        echo "Error: Too many arguments"
        exit 1
    fi
    shift
done

if [ -z "$class_moves_file" ] || [ -z "$repo_list_file" ] || [ -z "$repos_directory" ]; then
    echo "Usage: $0 <class_moves_file> <repo_list_file> <repos_directory>"
    echo "  class_moves_file: Path to file containing class moves (one per line)"
    echo "  repo_list_file: Path to file containing repository names (one per line)"
    echo "  repos_directory: Path to directory containing the repositories"
    echo ""
    echo "Class moves file format:"
    echo "  com.old.package.ClassName -> com.new.package.ClassName"
    echo "  com.old.package.OldName -> com.new.package.NewName"
    echo "  com.old.package.OuterClass.InnerClass -> com.new.package.InnerClass"
    echo "  # Comments start with #"
    echo ""
    echo "Examples:"
    echo "  # Move class to new package"
    echo "  com.knime.old.MyClass -> com.knime.new.MyClass"
    echo "  # Move and rename class"
    echo "  com.knime.old.OldName -> com.knime.new.NewName"
    echo "  # Move nested class"
    echo "  com.knime.old.Outer.Inner -> com.knime.new.Inner"
    exit 1
fi

if [ ! -f "$class_moves_file" ]; then
    echo "Error: Class moves file '$class_moves_file' not found"
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

# Function to extract class name from full class path
get_class_name() {
    local full_class="$1"
    echo "${full_class##*.}"
}

# Function to extract package from full class path
get_package() {
    local full_class="$1"
    local class_name=$(get_class_name "$full_class")
    echo "${full_class%.$class_name}"
}

# Function to generate sed patterns for a class move
generate_patterns() {
    local from_class="$1"
    local to_class="$2"
    
    local from_simple_name=$(get_class_name "$from_class")
    local to_simple_name=$(get_class_name "$to_class")
    
    # Escape dots for regex
    local from_class_escaped="${from_class//./\\.}"
    local to_class_escaped="${to_class//./\\.}"
    
    # Pattern 1: Update import statements (always needed)
    echo "s/import ${from_class_escaped}\b/import ${to_class_escaped}/g"
    
    # Pattern 2: If class name changed, update class references with word boundaries
    if [ "$from_simple_name" != "$to_simple_name" ]; then
        echo "s/\\b${from_simple_name}\\b/${to_simple_name}/g"
    fi
}

# Read class moves and generate patterns
patterns=()
while IFS= read -r line; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^# ]]; then
        continue
    fi
    
    # Parse the move: "from -> to"
    if [[ "$line" =~ ^([^-]+)\ *-\>\ *([^-]+)$ ]]; then
        from_class=$(echo "${BASH_REMATCH[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        to_class=$(echo "${BASH_REMATCH[2]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        echo "Processing move: $from_class -> $to_class"
        
        # Generate patterns for this move
        while IFS= read -r pattern; do
            if [ -n "$pattern" ]; then
                patterns+=("$pattern")
            fi
        done <<< "$(generate_patterns "$from_class" "$to_class")"
    else
        echo "Warning: Invalid move format: $line"
    fi
done < "$class_moves_file"

if [ ${#patterns[@]} -eq 0 ]; then
    echo "Error: No valid class moves found in '$class_moves_file'"
    exit 1
fi

echo "Generated ${#patterns[@]} refactoring pattern(s):"
for pattern in "${patterns[@]}"; do
    echo "  $pattern"
done
echo

# Process repositories
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
    
    # Find all .java files
    java_files=$(find . -name "*.java" -type f)
    
    if [ -z "$java_files" ]; then
        echo "  No .java files found"
        echo
        continue
    fi
    
    modified_files=()
    
    # Process each Java file
    while IFS= read -r java_file; do
        if [ -n "$java_file" ]; then
            # Apply all refactoring patterns in sequence directly to the file
            file_changed=false
            for pattern in "${patterns[@]}"; do
                if sed -i "" "$pattern" "$java_file" 2>/dev/null; then
                    file_changed=true
                fi
            done
            
            if [ "$file_changed" = true ]; then
                modified_files+=("$java_file")
            fi
        fi
    done <<< "$java_files"
    
    # Display results
    if [ ${#modified_files[@]} -eq 0 ]; then
        echo "  No changes needed"
    else
        echo -e "  \033[32mModified ${#modified_files[@]} file(s):\033[0m"
        
        for file in "${modified_files[@]}"; do
            # Remove leading ./ for cleaner output
            clean_file="${file#./}"
            echo -e "    \033[32m$clean_file\033[0m"
        done
    fi
    
    echo
    
done < "$repo_list_file"
