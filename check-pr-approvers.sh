#!/bin/bash
set -e

# These variables are automatically injected by Bitbucket Pipelines on a Pull Request build!
PR_ID=$BITBUCKET_PR_ID
WORKSPACE=$BITBUCKET_WORKSPACE
REPO_SLUG=$BITBUCKET_REPO_SLUG
API_TOKEN=$BITBUCKET_API_TOKEN

echo "==== Checking Required PR Approvers ===="

# 1. Check if running in a PR context
if [ -z "$PR_ID" ]; then
  echo "⚠️  Not running in a Pull Request context. Skipping check."
  exit 0
fi

# 2. Check for REQUIRED_CHECKERS environment variable
if [ -z "$REQUIRED_CHECKERS" ]; then
  echo "✅ REQUIRED_CHECKERS is not set. Skipping check."
  exit 0
fi

echo "REQUIRED_CHECKERS found. Validating approvals..."

# 3. Get the list of approvers
# Check if an environment variable for approvers is already supplied (e.g. bypass or injected)
# This handles the user's "in case there is an environment variable supplied" requirement.
if [ -n "$PR_APPROVERS_JSON" ]; then
  echo "Using provided PR_APPROVERS_JSON environment variable."
  CURRENT_APPROVERS_JSON="$PR_APPROVERS_JSON"
elif [ -n "$PR_APPROVERS" ]; then
  echo "Using provided PR_APPROVERS environment variable."
  # If they provide a comma-separated list, we'll wrap it in a pseudo-JSON for the Node script
  CURRENT_APPROVERS_JSON="{\"participants\": $(echo "$PR_APPROVERS" | node -pe "JSON.stringify(process.stdin.read().toString().split(',').map(name => ({user: {display_name: name.trim()}, approved: true})))")}"
else
  # Fallback to Bitbucket API
  if [ -z "$API_TOKEN" ]; then
    echo -e "\n\033[1;31m❌ ERROR: BITBUCKET_API_TOKEN is missing!\033[0m"
    echo "This script requires a BITBUCKET_API_TOKEN to fetch PR details from Bitbucket Cloud."
    exit 1
  fi

  echo "Fetching PR details from Bitbucket API..."
  CURRENT_APPROVERS_JSON=$(curl -s -H "Authorization: Bearer $API_TOKEN" "https://api.bitbucket.org/2.0/repositories/$WORKSPACE/$REPO_SLUG/pullrequests/$PR_ID")
fi

# 4. Use Node to perform the check (more robust than shell for names with spaces/special chars)
MISSING=$(node -e "
try {
  const data = JSON.parse(process.argv[1]);
  const reqStr = process.argv[2] || '';
  
  // Parse REQUIRED_CHECKERS: try JSON array first, then comma-separated
  let required;
  try {
    required = JSON.parse(reqStr);
    if (!Array.isArray(required)) required = [required];
  } catch (e) {
    required = reqStr.split(/[,|]/).map(s => s.trim());
  }
  required = required.map(s => String(s).toLowerCase()).filter(s => s);
  
  if (required.length === 0) process.exit(0);

  const participants = data.participants || [];
  const approvers = participants
    .filter(p => p.approved === true)
    .flatMap(p => [
      p.user.display_name?.toLowerCase(),
      p.user.nickname?.toLowerCase(),
      p.user.account_id?.toLowerCase()
    ])
    .filter(s => s);

  const missing = required.filter(r => !approvers.includes(r));
  if (missing.length > 0) {
    process.stdout.write(missing.join(', '));
    process.exit(1);
  }
} catch (e) {
  process.stderr.write('Error parsing PR data: ' + e.message);
  process.exit(1);
}
" "$CURRENT_APPROVERS_JSON" "$REQUIRED_CHECKERS")

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo -e "\n\033[1;31m❌ ERROR: Mandatory PR Approvers Missing\033[0m"
  if [ -n "$MISSING" ]; then
    echo "The following required checkers have not yet approved this PR:"
    echo "$MISSING" | tr ',' '\n' | sed 's/^/ - /'
  else
    echo "Failed to verify approvers. Ensure BITBUCKET_API_TOKEN is valid and REQUIRED_CHECKERS is formatted correctly."
  fi
  exit 1
fi

echo -e "\n\033[1;32m✅ SUCCESS: All required checkers ($REQUIRED_CHECKERS) have approved this PR!\033[0m\n"
exit 0
