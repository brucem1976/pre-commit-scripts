# Common functions for JIRA compliance checks
# Source this file in other scripts: source "$(dirname "$0")/common.sh"

# JIRA branch name regex pattern
readonly JIRA_BRANCH_REGEX="^(feature|task|bugfix)/[[:upper:]]+-[0-9]+(-[[:lower:]0-9]+)*$"

# Extract JIRA ticket from branch name
# Usage: extract_jira_ticket "$branch_name"
# Returns: JIRA ticket (e.g., "ABC-123") or empty string if not found
extract_jira_ticket() {
  local branch_name="$1"
  if [[ $branch_name =~ ^(feature|task|bugfix)/([[:upper:]]+-[0-9]+) ]]; then
    echo "${BASH_REMATCH[2]}"
  fi
}

# Validate branch name format
# Usage: validate_branch_name "$branch_name"
# Returns: 0 if valid, 1 if invalid
validate_branch_name() {
  local branch_name="$1"
  [[ $branch_name =~ $JIRA_BRANCH_REGEX ]]
}

# Validate commit message starts with JIRA ticket
# Usage: validate_commit_message "$commit_message" "$jira_ticket"
# Returns: 0 if valid, 1 if invalid
validate_commit_message() {
  local commit_message="$1"
  local jira_ticket="$2"
  [[ "$commit_message" == "$jira_ticket: "* ]]
}

# Check for unauthorized dependency file changes
# Usage: check_dependency_changes "$changed_files"
# Returns: 0 if no changes, 1 if unauthorized changes found
check_dependency_changes() {
  local changed_files="$1"
  echo "$changed_files" | grep -qE "yarn\.lock|package-lock\.json|package\.json"
}

# Get current branch name
# Usage: get_current_branch
# Returns: branch name
get_current_branch() {
  git rev-parse --abbrev-ref HEAD
}

# Error message functions for consistent output
error_invalid_branch() {
  local branch_name="$1"
  echo -e "\n\033[1;31m❌ ERROR: Invalid Git Branch Name: '$branch_name'\033[0m"
  echo -e "You cannot commit unless your branch strictly matches the JIRA convention."
  echo -e "\n\033[1;33mExpected Format:\033[0m   (feature|task|bugfix)/ABC-1234-hyphenated-lowercase"
  echo -e "\033[1;32mCorrect Example:\033[0m   feature/LOG-892-add-login-button"
  echo -e "\033[1;31mIncorrect Example:\033[0m feature/log-892-add-Login_Button"
  echo -e "\nPlease rename your branch using: \033[1;36mgit branch -m <new-name>\033[0m\n"
}

error_invalid_commit_message() {
  local branch_name="$1"
  local ticket="$2"
  echo -e "\n\033[1;31m❌ ERROR: Invalid Commit Message format!\033[0m"
  echo -e "Because you are currently on branch '\033[1;36m$branch_name\033[0m',"
  echo -e "your commit message MUST begin with the matching JIRA ticket."
  echo -e "\n\033[1;33mExpected Prefix:\033[0m \033[1;37m$ticket: \033[0m"
  echo -e "\n\033[1;32mCorrect Example:\033[0m   git commit -m \"$ticket: Fixed the login screen UI\""
  echo -e "\033[1;31mIncorrect Example:\033[0m git commit -m \"fixed the login screen UI\"\n"
}

error_unauthorized_dependency_change() {
  echo -e "\n\033[1;31m❌ ERROR: Unauthorized Dependency Change Detected!\033[0m"
  echo "You have modified a configuration file ('package.json', 'yarn.lock' or 'package-lock.json') in this Pull Request."
  echo "Developers are explicitly forbidden from upgrading or adding new NPM dependencies natively."
  echo "Please revert your changes to pass this Pipeline."
}