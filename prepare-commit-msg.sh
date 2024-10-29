#!/bin/sh
# prepare-commit-msg

# Exit if no commit message file is provided
if [ -z "$1" ]; then
    echo "Error: No commit message file provided"
    exit 1
fi

COMMIT_MSG_FILE="$1"
COMMIT_SOURCE="$2"

# Validate that commit message file exists
if [ ! -f "$COMMIT_MSG_FILE" ]; then
    echo "Error: Commit message file does not exist: $COMMIT_MSG_FILE"
    exit 1
fi

# Check if .env file exists and byulBash is set to true
if [ -f .env ]; then
    byul_bash=$(grep '^byulBash=' .env | cut -d '=' -f2)
    if [ "$byul_bash" != "true" ]; then
        exit 0
    fi
else
    exit 0
fi

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_color() {
    printf "${1}${2}${NC}\n"
}

read_json_value() {
    json_file="$1"
    key="$2"
    sed -n "s/^.*\"$key\": *\"\\(.*\\)\".*$/\\1/p" "$json_file" | sed 's/,$//'
}

format_commit_message() {
    commit_msg_file="$1"
    commit_source="$2"
    branch_name=$(git symbolic-ref --short HEAD)
    branch_type=""
    issue_number=""

    json_file=$(git rev-parse --show-toplevel)/byul.config.json
    if [ ! -f "$json_file" ]; then
        print_color "$YELLOW" "Warning: byul.config.json not found. Using default format."
        byul_format="{type}: {commitMessage} (#{issueNumber})"
    else
        byul_format=$(read_json_value "$json_file" "byulFormat")
        if [ -z "$byul_format" ]; then
            print_color "$YELLOW" "Warning: byulFormat not found in config. Using default format."
            byul_format="{type}: {commitMessage} (#{issueNumber})"
        fi
    fi

    if ! echo "$branch_name" | grep -q "/"; then
        print_color "$YELLOW" "Branch name does not contain '/'. Skipping formatting."
        return 1
    fi

    parts=$(echo "$branch_name" | tr "/" "\n")
    num_parts=$(echo "$parts" | wc -l)
    if [ $num_parts -ge 2 ]; then
        branch_type=$(echo "$parts" | sed -n "$(($num_parts-1))p")
    else
        branch_type=$(echo "$parts" | sed -n "1p")
    fi

    last_part=$(echo "$branch_name" | sed 's/.*\///')
    issue_number=$(echo "$last_part" | sed -n 's/.*-\([0-9]\+\)$/\1/p')

    if [ "$commit_source" = "message" ]; then
        # For -m flag commits, use the original behavior
        first_line=$(head -n 1 "$commit_msg_file")
        
        if [ -n "$branch_type" ]; then
            formatted_msg=$(echo "$byul_format" |
                sed "s/{type}/$branch_type/g" |
                sed "s/{commitMessage}/$first_line/g" |
                sed "s/{issueNumber}/$issue_number/g")

            echo "$formatted_msg" > "$commit_msg_file.tmp"
            tail -n +2 "$commit_msg_file" >> "$commit_msg_file.tmp"
            mv "$commit_msg_file.tmp" "$commit_msg_file"
        fi
    else
        # Get template comments (starting from the first #)
        template_start=$(grep -n "^#" "$commit_msg_file" | head -n 1 | cut -d: -f1)
        
        if [ -n "$branch_type" ]; then
            formatted_msg=$(echo "$byul_format" |
                sed "s/{type}/$branch_type/g" |
                sed "s/{commitMessage}//g" |
                sed "s/{issueNumber}/$issue_number/g")
            
            formatted_msg=$(echo "$formatted_msg" | sed 's/:  */: /g')

            # Create temporary file
            tmp_file="${commit_msg_file}.tmp"
            
            # Add formatted message
            echo "$formatted_msg" > "$tmp_file"
            
            # Add a blank line after the formatted message
            echo "" >> "$tmp_file"
            
            # Append all lines from template_start to the end of the file
            if [ -n "$template_start" ]; then
                tail -n +"$template_start" "$commit_msg_file" >> "$tmp_file"
            fi
            
            # Replace the original file
            mv "$tmp_file" "$commit_msg_file"
        fi
    fi

    print_color "$GREEN" "✔ Commit message formatted successfully!"
    print_color "$BLUE" "New commit message: $formatted_msg"
    return 0
}

# Check if the commit is a merge, squash, or amend
if [ "$COMMIT_SOURCE" = "merge" ] || [ "$COMMIT_SOURCE" = "squash" ] || [ "$COMMIT_SOURCE" = "commit" ]; then
    print_color "$BLUE" "Merge, squash, or amend commit detected. Skipping formatting."
    exit 0
fi

if format_commit_message "$COMMIT_MSG_FILE" "$COMMIT_SOURCE"; then
    exit 0
else
    print_color "$RED" "❌ Failed to format commit message."
    exit 0
fi
