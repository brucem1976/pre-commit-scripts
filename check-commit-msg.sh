#!/bin/bash

# Source common functions
source "$(dirname "$0")/common.sh"

# pre-commit passes the path to the commit message file as the first argument
COMMIT_MSG_FILE=$1
BRANCH_NAME=$(get_current_branch)

# Extract the Jira ticket from the branch name
TICKET=$(extract_jira_ticket "$BRANCH_NAME")
if [ -z "$TICKET" ]; then
  # If the branch doesn't conform, our branch-name hook will catch it separately
  exit 0
fi

# Extract just the first line (the commit title)
FIRST_LINE=$(head -n 1 "$COMMIT_MSG_FILE")

# Check if the title starts exactly with the ticket followed by a colon and a space
if ! validate_commit_message "$FIRST_LINE" "$TICKET"; then
  error_invalid_commit_message "$BRANCH_NAME" "$TICKET"
  exit 1
fi

exit 0
