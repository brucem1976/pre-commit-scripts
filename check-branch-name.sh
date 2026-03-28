#!/bin/bash

# Source common functions
source "$(dirname "$0")/common.sh"

# Extract the current branch name
BRANCH_NAME=$(get_current_branch)

# Validate branch name format
if ! validate_branch_name "$BRANCH_NAME"; then
  error_invalid_branch "$BRANCH_NAME"
  exit 1
fi

exit 0
