#!/bin/sh
read_json_value() {
    json_file="$1"
    key="$2"
    sed -n "s/^.*\"$key\": *\"\\(.*\\)\".*$/\\1/p" "$json_file" | sed 's/,$//'
}

format_commit_message() {
    commit_msg_file="$1"
    branch_name=$(git symbolic-ref --short HEAD)
    branch_type=""
    issue_number=""

    json_file=$(git rev-parse --show-toplevel)/byul.config.json
    byul_format=$(read_json_value "$json_file" "byulFormat")

    if ! echo "$branch_name" | grep -q "/"; then
        return
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

    first_line=$(sed -n '1p' "$commit_msg_file")

    if [ -n "$branch_type" ]; then
        formatted_msg=$(echo "$byul_format" |
            sed "s/{type}/$branch_type/g" |
            sed "s/{commitMessage}/$first_line/g" |
            sed "s/{issueNumber}/$issue_number/g")

        sed -i.bak "1s/.*/$formatted_msg/" "$commit_msg_file"
    fi

    rm "${commit_msg_file}.bak"
}

COMMIT_MSG_FILE="$1"
COMMIT_SOURCE="$2"

if [ "$COMMIT_SOURCE" = "merge" ]; then
    exit 0
fi

format_commit_message "$COMMIT_MSG_FILE"

# format_commit_message() {
#     commit_msg_file="$1"
#     branch_name=$(git symbolic-ref --short HEAD)
#     branch_type=""
#     issue_number=""

#     if ! echo "$branch_name" | grep -q "/"; then
#         return
#     fi

#     parts=$(echo "$branch_name" | tr "/" "\n")
#     num_parts=$(echo "$parts" | wc -l)
#     if [ $num_parts -ge 2 ]; then
#         branch_type=$(echo "$parts" | sed -n "$(($num_parts-1))p")
#     else
#         branch_type=$(echo "$parts" | sed -n "1p")
#     fi

#     last_part=$(echo "$branch_name" | sed 's/.*\///')
#     issue_number=$(echo "$last_part" | sed -n 's/.*-\([0-9]\+\)$/\1/p')

#     if [ -n "$branch_type" ]; then
#         sed -i.bak "1s/^/$branch_type: /" "$commit_msg_file"
#         if [ -n "$issue_number" ]; then
#             sed -i.bak "1s/$/ (#$issue_number)/" "$commit_msg_file"
#         fi
#     fi

#     rm "${commit_msg_file}.bak"
# }

# COMMIT_MSG_FILE="$1"
# COMMIT_SOURCE="$2"

# if [ "$COMMIT_SOURCE" = "merge" ]; then
#     exit 0
# fi

# format_commit_message "$COMMIT_MSG_FILE"

