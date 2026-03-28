#!/bin/bash

# pre-commit passes the path to the commit message file as the first argument
COMMIT_MSG_FILE=$1
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

# Skip for non-feature branches
if [[ "$BRANCH_NAME" == "main" || "$BRANCH_NAME" == "master" || "$BRANCH_NAME" == "HEAD" ]]; then
  exit 0
fi

# Extract the Jira ticket from the branch name using regex
# This strictly extracts the ticket ONLY if the JIRA project key is Uppercase
if [[ $BRANCH_NAME =~ ^(feature|task|bugfix)/([[:upper:]]+-[0-9]+) ]]; then
  TICKET="${BASH_REMATCH[2]}"
else
  # If the branch doesn't conform, our branch-name hook will catch it separately
  exit 0
fi

# Extract just the first line (the commit title)
FIRST_LINE=$(head -n 1 "$COMMIT_MSG_FILE")

# Check if the title starts exactly with the ticket followed by a colon and a space
if [[ ! "$FIRST_LINE" == "$TICKET: "* ]]; then
  echo -e "\n\033[1;31m❌ ERROR: Invalid Commit Message format!\033[0m"
  echo -e "Because you are currently on branch '\033[1;36m$BRANCH_NAME\033[0m',"
  echo -e "your commit message MUST begin with the matching JIRA ticket."
  echo -e "\n\033[1;33mExpected Prefix:\033[0m \033[1;37m$TICKET: \033[0m"
  echo -e "\n\033[1;32mCorrect Example:\033[0m   git commit -m \"$TICKET: Fixed the login screen UI\""
  echo -e "\033[1;31mIncorrect Example:\033[0m git commit -m \"fixed the login screen UI\"\n"
  exit 1
fi

exit 0
