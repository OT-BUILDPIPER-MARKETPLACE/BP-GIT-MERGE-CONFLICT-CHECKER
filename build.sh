#!/bin/bash

# ---------------------------------------------------------------
# NOTE: ACTIVITY_SUB_TASK_CODE is managed by the BuildPiper
#       environment. Do NOT override it here to ensure events
#       appear correctly in the UI.
# ---------------------------------------------------------------

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

if [ "$DEBUG" = true ]; then
    set -x
fi

# ---------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------
WORKSPACE="${WORKSPACE:-/bp/workspace}"
CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
TASK_STATUS=0

# ---------------------------------------------------------------
# 1. Initialization
# ---------------------------------------------------------------
logInfoMessage "> Starting step: git_merge_conflict_checker"
logInfoMessage "> Codebase location: ${CODEBASE_LOCATION}"
logInfoMessage "> Target branch: ${TARGET_BRANCH}"

add_event "INITIALIZATION" "Successful" \
    "Git Merge Conflict Checker step initialized" \
    "Target Branch: ${TARGET_BRANCH} | Codebase: ${CODEBASE_DIR}"

if [ -n "$SLEEP_DURATION" ] && [ "$SLEEP_DURATION" -gt 0 ] 2>/dev/null; then
    logInfoMessage "> Sleeping for ${SLEEP_DURATION} second(s)..."
    sleep "$SLEEP_DURATION"
fi

# ---------------------------------------------------------------
# 2. Input Validation
# ---------------------------------------------------------------
logInfoMessage "> Validating inputs..."

if [ -z "$WORKSPACE" ] || [ -z "$CODEBASE_DIR" ]; then
    logErrorMessage "> WORKSPACE or CODEBASE_DIR is not set — cannot proceed"
    add_event "INPUT_VALIDATION" "Failed" \
        "Required environment variables are missing" \
        "WORKSPACE: ${WORKSPACE:-<unset>} | CODEBASE_DIR: ${CODEBASE_DIR:-<unset>}"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

if [ -z "$TARGET_BRANCH" ]; then
    logErrorMessage "> TARGET_BRANCH is not set — cannot proceed"
    add_event "INPUT_VALIDATION" "Failed" \
        "TARGET_BRANCH is not set" \
        "Set TARGET_BRANCH to the branch to check for merge conflicts against"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

add_event "INPUT_VALIDATION" "Successful" \
    "All required inputs validated" \
    "Target Branch: ${TARGET_BRANCH} | Codebase: ${CODEBASE_DIR}"

# ---------------------------------------------------------------
# 3. Execution Summary
# ---------------------------------------------------------------
echo ""
echo "> Git Merge Conflict Checker Execution Summary"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Parameter" "Value"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Codebase" "${CODEBASE_DIR}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Codebase Path" "${CODEBASE_LOCATION}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
printf '| %-28s | %-48s |\n' "Target Branch" "${TARGET_BRANCH}"
printf '+%-30s+%-50s+\n' '------------------------------' '--------------------------------------------------'
echo ""

# ---------------------------------------------------------------
# 4. Workspace Navigation
# ---------------------------------------------------------------
logInfoMessage "> Navigating to codebase directory..."

cd "${CODEBASE_LOCATION}" || {
    logErrorMessage "> Failed to navigate to codebase directory: ${CODEBASE_LOCATION}"
    add_event "WORKSPACE_NAVIGATION" "Failed" \
        "Cannot change to codebase directory" \
        "Path: ${CODEBASE_LOCATION} | Verify WORKSPACE and CODEBASE_DIR"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
}

logInfoMessage "> Successfully navigated to: ${CODEBASE_LOCATION}"
add_event "WORKSPACE_NAVIGATION" "Successful" \
    "Navigated to codebase directory" \
    "Path: ${CODEBASE_LOCATION}"

# ---------------------------------------------------------------
# 5. Git Fetch Target Branch
# ---------------------------------------------------------------
logInfoMessage "> Fetching remote branch: ${TARGET_BRANCH}..."

if ! git fetch origin "$TARGET_BRANCH" 2>&1; then
    logErrorMessage "> Failed to fetch remote branch: ${TARGET_BRANCH}"
    add_event "GIT_FETCH" "Failed" \
        "Failed to fetch target branch from remote" \
        "Branch: ${TARGET_BRANCH} | Verify branch name and remote connectivity"
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

logInfoMessage "> Fetched remote branch successfully: ${TARGET_BRANCH}"
add_event "GIT_FETCH" "Successful" \
    "Target branch fetched from remote" \
    "Branch: ${TARGET_BRANCH}"

# ---------------------------------------------------------------
# 6. Merge Conflict Check
# ---------------------------------------------------------------
logInfoMessage "> Running merge conflict check against: origin/${TARGET_BRANCH}..."
add_event "CONFLICT_CHECK_START" "Successful" \
    "Starting merge conflict simulation" \
    "Simulating merge with: origin/${TARGET_BRANCH}"

# Attempt a dry-run merge (no-commit, no-ff); errors are expected on conflict
git merge --no-commit --no-ff "origin/${TARGET_BRANCH}" 2>/dev/null || true

CONFLICTED_FILES=$(git diff --name-only --diff-filter=U)

if [ -n "$CONFLICTED_FILES" ]; then
    CONFLICT_COUNT=$(echo "$CONFLICTED_FILES" | wc -l | tr -d ' ')
    logErrorMessage "> Merge conflicts detected with origin/${TARGET_BRANCH} (${CONFLICT_COUNT} file(s)):"
    echo "$CONFLICTED_FILES" | while read -r f; do
        logErrorMessage ">   - ${f}"
    done
    add_event "CONFLICT_CHECK_RESULT" "Failed" \
        "Merge conflicts detected — merge cannot proceed cleanly" \
        "Branch: ${TARGET_BRANCH} | Conflicted files: ${CONFLICT_COUNT}"
    git merge --abort 2>/dev/null || true
    saveTaskStatus 1 "${ACTIVITY_SUB_TASK_CODE}"
    exit 1
fi

logInfoMessage "> No merge conflicts found with origin/${TARGET_BRANCH}"
add_event "CONFLICT_CHECK_RESULT" "Successful" \
    "No merge conflicts detected — clean merge possible" \
    "Branch: ${TARGET_BRANCH} | All files merge cleanly"

git merge --abort 2>/dev/null || true

# ---------------------------------------------------------------
# 7. Final Status
# ---------------------------------------------------------------
logInfoMessage "> Git Merge Conflict Checker step completed successfully"
saveTaskStatus 0 "${ACTIVITY_SUB_TASK_CODE}"
exit 0
