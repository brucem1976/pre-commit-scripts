#!/bin/bash
set -e

# These variables are automatically injected by Bitbucket Pipelines on a Pull Request build!
BRANCH=$BITBUCKET_BRANCH
DEST_BRANCH=$BITBUCKET_PR_DESTINATION_BRANCH
PR_ID=$BITBUCKET_PR_ID

echo "==== 1. Validating PR Branch Name ===="
REGEX="^(feature|task|bugfix)/[[:upper:]]+-[0-9]+(-[[:lower:]0-9]+)*$"

if [[ ! $BRANCH =~ $REGEX ]]; then
  echo -e "\n\033[1;31m❌ ERROR: Invalid Branch Name: '$BRANCH'\033[0m"
  echo "Branch must match: (feature|task|bugfix)/ABC-1234-lowercase-words"
  exit 1
fi
echo "✅ Branch Name is perfectly formatted."

# Extract Ticket for commit/title checks
if [[ $BRANCH =~ ^(feature|task|bugfix)/([[:upper:]]+-[0-9]+) ]]; then
  TICKET="${BASH_REMATCH[2]}"
fi

echo ""
echo "==== 2. Validating All Commit Messages in PR ===="
if [ -z "$DEST_BRANCH" ]; then
  echo "⚠️  Not running in a PR context. Skipping Commit Message comparisons."
else
  # Bitbucket does shallow clones. We must fetch the destination branch to compare against.
  git fetch origin "$DEST_BRANCH" > /dev/null 2>&1

  COMMITS=$(git rev-list origin/$DEST_BRANCH..HEAD)

  for COMMIT in $COMMITS; do
    MESSAGE=$(git log --format=%B -n 1 $COMMIT | head -n 1)
    if [[ ! "$MESSAGE" == "$TICKET: "* ]]; then
      echo -e "\n\033[1;31m❌ ERROR: Invalid Commit Message in commit: $COMMIT\033[0m"
      echo "Message typed: '$MESSAGE'"
      echo "Every individual commit in this PR MUST start exactly with: '$TICKET: '"
      exit 1
    fi
  done
  echo "✅ All Commit Messages in this Pipeline run are perfectly formatted."
fi

echo ""
echo "==== 3. Validating Pull Request Title ===="
if [ -z "$PR_ID" ]; then
  echo "⚠️  Not running in a PR context. Skipping PR Title check."
else
  if [ -z "$BITBUCKET_API_TOKEN" ]; then
    echo -e "\n\033[1;33m⚠️  WARNING: BITBUCKET_API_TOKEN is missing!\033[0m"
    echo "Since this is a Private Repository, you must create a Workspace Variable named 'BITBUCKET_API_TOKEN' (containing a Workspace Access Token) so the Pipeline can read the PR Title."
    echo "Skipping the PR Title validation for now..."
  else
    # Fetch PR title using Bitbucket API safely via the configured Workspace Variable Bearer Token
    JSON_PAYLOAD=$(curl -s -H "Authorization: Bearer $BITBUCKET_API_TOKEN" "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO_SLUG/pullrequests/$PR_ID")
    
    # Parse safely using NodeJS 
    PR_TITLE=$(node -pe "JSON.parse(process.argv[1]).title" "$JSON_PAYLOAD")

    if [[ ! "$PR_TITLE" == "$TICKET: "* ]]; then
      echo -e "\n\033[1;31m❌ ERROR: Invalid Pull Request Title\033[0m"
      echo "Title: '$PR_TITLE'"
      echo "The PR title MUST start exactly with: '$TICKET: '"
      exit 1
    fi
    echo "✅ PR Title is perfectly formatted."
  fi
fi

echo ""
echo "==== 4. Restricting Dependency Updates ===="
if [ -n "$DEST_BRANCH" ]; then
  # Find all files modified in this specific Pull Request
  CHANGED_FILES=$(git diff --name-only origin/$DEST_BRANCH...HEAD || true)
  
  if echo "$CHANGED_FILES" | grep -qE "yarn\.lock|package-lock\.json"; then
    echo -e "\n\033[1;31m❌ ERROR: Unauthorized Dependency Change Detected!\033[0m"
    echo "You have modified a lockfile ('yarn.lock' or 'package-lock.json') in this Pull Request."
    echo "Developers are explicitly forbidden from upgrading or adding new NPM dependencies natively."
    echo "Please revert your lockfiles to pass this Pipeline."
    exit 1
  fi
  echo "✅ No unauthorized dependency lockfiles were modified."
fi

echo -e "\n\033[1;32m🎉 Success! Entire Pull Request complies with all JIRA standards!\033[0m\n"
