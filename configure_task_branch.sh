#!/bin/bash

###############################################################################
# Script: configure_task_branch.sh

# Description:
#   This script creates a new Git branch configured with specific versions of 
#   files captured as arguments and generates a `config.yml` file to capture those versions.
#
#   It optionally allows specifying commit hashes and source branches for the 
#   prompt files. If not provided, the latest commits from base branch
#   are used. The script checks out those file versions, commits them along with 
#   the config file, and prepares a new branch for pushing.
#
# Usage:
#   ./configure_task_branch.sh [OPTIONS]
#
# Options:
#   --username <username>                 # Username to prefix the branch name
#   --selection_prompt <commit_hash>      # Commit hash for selection_prompt.txt
#   --rerank_prompt <commit_hash>         # Commit hash for rerank_prompt.txt
#   --base_branch <branch>                # Base branch to create new branch from
#   --selection_prompt_branch <branch>    # Branch to fetch selection prompt hash from
#   --rerank_prompt_branch <branch>       # Branch to fetch rerank prompt hash from
#
# Example:
#   ./configure_task_branch.sh \
#     --username test \
#     --selection_prompt abcd1234\
#     --rerank_prompt 4321dcba
#
# Notes:
#   - By default, all branches default to "dev" unless overridden.
#   - The new branch is named <username>-<timestamp>.
###############################################################################

# Function to get branch name that contains a given commit
get_branch_for_commit() {
    local commit_hash=$1
    local fallback_branch=$2

    # Try to find local branch
    branch_name=$(git branch --contains "$commit_hash" --format="%(refname:short)" | head -n 1)

    # If not found locally, try remote
    if [ -z "$branch_name" ]; then
        branch_name=$(git for-each-ref --format="%(refname:short)" --contains "$commit_hash" refs/remotes | head -n 1)
    fi

    echo "${branch_name:-$fallback_branch}"
}

# FILE_PROMPT_SELECTION="RAJ/prompts/selection_prompt.txt"
# FILE_PROMPT_RERANK="RAJ/prompts/rerank_prompt.txt"
FILE_PROMPT_SELECTION=./prompt/selection.txt
FILE_PROMPT_RERANK=./prompt/rerank.txt
JOB_CONFIG_DIR="./config"
JOB_CONFIG_FILE="${JOB_CONFIG_DIR}/config.yml"
JOB_CONFIG_JSON_FILE="${JOB_CONFIG_DIR}/config.json"

# default values for optional parameters
USERNAME="stephen"
BASE_BRANCH="dev"
SELECTION_PROMPT_BRANCH=""
RERANK_PROMPT_BRANCH=""

# parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --username) USERNAME="$2"; shift ;;
        --selection_prompt) SELECTION_PROMPT_COMMIT_HASH="$2"; shift ;;
        --rerank_prompt) RERANK_PROMPT_COMMIT_HASH="$2"; shift ;;
        --base_branch) BASE_BRANCH="$2"; shift ;;
        --selection_prompt_branch) SELECTION_PROMPT_BRANCH="$2"; shift ;;
        --rerank_prompt_branch) RERANK_PROMPT_BRANCH="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# set default source branches for commit hashes if not provided
SELECTION_PROMPT_BRANCH=${SELECTION_PROMPT_BRANCH:-$BASE_BRANCH}
RERANK_PROMPT_BRANCH=${RERANK_PROMPT_BRANCH:-$BASE_BRANCH}

# get default commit hashes from the specified source branches
CURRENT_BRANCH=$BASE_BRANCH
echo ">> Current branch: $CURRENT_BRANCH"

# ensure working directory is clean
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "❌ Error: You have uncommitted changes. Please commit or stash them before running this script."
    exit 1
fi

# get default commit hash for FILE_PROMPT_SELECTION
echo ">> Getting default commit hash for $FILE_PROMPT_SELECTION from branch $SELECTION_PROMPT_BRANCH"
if ! git show "$SELECTION_PROMPT_BRANCH:$FILE_PROMPT_SELECTION" > /dev/null 2>&1; then
    echo "❌ Error: File '$FILE_PROMPT_SELECTION' not found in branch '$SELECTION_PROMPT_BRANCH'"
    exit 1
fi
DEFAULT_SELECTION_PROMPT_COMMIT_HASH=$(git log -n 1 --pretty=format:"%H" "$SELECTION_PROMPT_BRANCH" -- "$FILE_PROMPT_SELECTION")
echo "  - Default commit hash for $FILE_PROMPT_SELECTION: $DEFAULT_SELECTION_PROMPT_COMMIT_HASH"

# get default commit hash for FILE_PROMPT_RERANK
echo ">> Getting default commit hash for $FILE_PROMPT_RERANK from branch $RERANK_PROMPT_BRANCH"
if ! git show "$RERANK_PROMPT_BRANCH:$FILE_PROMPT_RERANK" > /dev/null 2>&1; then
    echo "❌ Error: File '$FILE_PROMPT_RERANK' not found in branch '$RERANK_PROMPT_BRANCH'"
    exit 1
fi
DEFAULT_RERANK_PROMPT_COMMIT_HASH=$(git log -n 1 --pretty=format:"%H" "$RERANK_PROMPT_BRANCH" -- "$FILE_PROMPT_RERANK")
echo "  - Default commit hash for $FILE_PROMPT_RERANK: $DEFAULT_RERANK_PROMPT_COMMIT_HASH"

# use provided commit hash if available, otherwise fallback to default
SELECTION_PROMPT_COMMIT_HASH=${SELECTION_PROMPT_COMMIT_HASH:-$DEFAULT_SELECTION_PROMPT_COMMIT_HASH}
RERANK_PROMPT_COMMIT_HASH=${RERANK_PROMPT_COMMIT_HASH:-$DEFAULT_RERANK_PROMPT_COMMIT_HASH}

# determine branch names for commit hashes
SELECTION_PROMPT_COMMIT_BRANCH=$(get_branch_for_commit "$SELECTION_PROMPT_COMMIT_HASH" "$SELECTION_PROMPT_BRANCH")
RERANK_PROMPT_COMMIT_BRANCH=$(get_branch_for_commit "$RERANK_PROMPT_COMMIT_HASH" "$RERANK_PROMPT_BRANCH")

# checkout base branch before continuing
echo ">> Checking out base branch: $BASE_BRANCH"
git checkout $BASE_BRANCH

# generate branch name with timestamp
TIMESTAMP=$(date +"%m-%d_%H-%M-%S")
BRANCH_NAME="${USERNAME}-${TIMESTAMP}"

echo ">> Creating new branch: $BRANCH_NAME"
git checkout -b $BRANCH_NAME

# Pulling specific versions of files first to get their contents
echo ">> Pulling specific versions of files..."
git checkout $SELECTION_PROMPT_COMMIT_HASH -- $FILE_PROMPT_SELECTION
git checkout $RERANK_PROMPT_COMMIT_HASH -- $FILE_PROMPT_RERANK

# Get file contents
SELECTION_PROMPT_CONTENT=$(cat $FILE_PROMPT_SELECTION)
RERANK_PROMPT_CONTENT=$(cat $FILE_PROMPT_RERANK)

echo ">> Creating job config file: $JOB_CONFIG_FILE"
echo ">> Creating job config JSON file: $JOB_CONFIG_JSON_FILE"
mkdir -p $JOB_CONFIG_DIR

# Create YAML config file with file contents
cat <<EOF > $JOB_CONFIG_FILE
base_branch: $BASE_BRANCH
branch_name: $BRANCH_NAME
files:
  - path: $FILE_PROMPT_SELECTION
    commit_hash: $SELECTION_PROMPT_COMMIT_HASH
    source_branch: $SELECTION_PROMPT_COMMIT_BRANCH
    content: |
$(echo "$SELECTION_PROMPT_CONTENT" | sed 's/^/      /')
  - path: $FILE_PROMPT_RERANK
    commit_hash: $RERANK_PROMPT_COMMIT_HASH
    source_branch: $RERANK_PROMPT_COMMIT_BRANCH
    content: |
$(echo "$RERANK_PROMPT_CONTENT" | sed 's/^/      /')
EOF

# Create JSON config file with file contents
# use printf to properly escape the content for JSON
printf '{
  "username": "%s",
  "base_branch": "%s",
  "branch_name": "%s",
  "files": [
    {
      "path": "%s",
      "commit_hash": "%s",
      "source_branch": "%s",
      "content": "%s"
    },
    {
      "path": "%s",
      "commit_hash": "%s",
      "source_branch": "%s",
      "content": "%s"
    }
  ]
}'  "$USERNAME" \
    "$BASE_BRANCH" \
    "$BRANCH_NAME" \
    "$FILE_PROMPT_SELECTION" \
    "$SELECTION_PROMPT_COMMIT_HASH" \
    "$SELECTION_PROMPT_COMMIT_BRANCH" \
    "$(echo "$SELECTION_PROMPT_CONTENT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\n/\\n/g')" \
    "$FILE_PROMPT_RERANK" \
    "$RERANK_PROMPT_COMMIT_HASH" \
    "$RERANK_PROMPT_COMMIT_BRANCH" \
    "$(echo "$RERANK_PROMPT_CONTENT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\n/\\n/g')" > $JOB_CONFIG_JSON_FILE
    

# Read MongoDB connection URL from .env
MONGODB_CONNECTION_URL=$(grep MONGODB_CONNECTION_URL .env | cut -d '=' -f2- | tr -d '"')

# Save JSON content to MongoDB
echo ">> Saving config.json to MongoDB collection 'submissions' in database 'dataflexx'..."
if command -v mongoimport &> /dev/null
then
    mongoimport --uri "$MONGODB_CONNECTION_URL" --db dataflexx --collection submissions --file "$JOB_CONFIG_JSON_FILE"
else
    echo "⚠️ Warning: mongoimport command not found. Please install MongoDB Database Tools to save data to MongoDB."
fi

echo ">> Adding job config file and specific file versions to git..."
git add $JOB_CONFIG_JSON_FILE
git add $JOB_CONFIG_FILE $FILE_PROMPT_SELECTION $FILE_PROMPT_RERANK

echo ">> Committing changes..."
git commit -m "Configure job with specific file versions for branch $BRANCH_NAME and JSON config with file contents"
echo ">> Pushing new branch to remote..."
git push origin $BRANCH_NAME
git checkout $BASE_BRANCH

echo ">> fin"
