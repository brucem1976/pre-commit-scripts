#!/bin/bash

# Extract the current branch name
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

# Optionally silently pass if a developer is committing directly to main or master
if [[ "$BRANCH_NAME" == "main" || "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "HEAD" ]]; then
  exit 0
fi

# REGEX Breakdown:
# ^(feature|task|bugfix)/   -> Must start with one of these three prefixes
# [[:upper:]]+-[0-9]+       -> Must be followed by a standard JIRA ticket (STRICTLY UPPERCASE)
# (-[[:lower:]0-9]+)*$      -> Optionally followed by hyphenated-lowercase-words
REGEX="^(feature|task|bugfix)/[[:upper:]]+-[0-9]+(-[[:lower:]0-9]+)*$"

if [[ ! $BRANCH_NAME =~ $REGEX ]]; then
  echo -e "\n\033[1;31m❌ ERROR: Invalid Git Branch Name: '$BRANCH_NAME'\033[0m"
  echo -e "You cannot commit unless your branch strictly matches the JIRA convention."
  echo -e "\n\033[1;33mExpected Format:\033[0m   (feature|task|bugfix)/ABC-1234-hyphenated-lowercase"
  echo -e "\033[1;32mCorrect Example:\033[0m   feature/LOG-892-add-login-button"
  echo -e "\033[1;31mIncorrect Example:\033[0m feature/log-892-add-Login_Button"
  echo -e "\nPlease rename your branch using: \033[1;36mgit branch -m <new-name>\033[0m\n"
  exit 1
fi

exit 0
