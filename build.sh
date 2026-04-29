#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

TASK_STATUS=0

CODEBASE_LOCATION="${WORKSPACE}"/"${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION
cd  "${CODEBASE_LOCATION}" || {
    logErrorMessage "Failed to navigate to workspace: ${CODEBASE_LOCATION}"
    add_event "WORKSPACE NAVIGATION" "Failed" \
          "Failed to navigate to workspace" \
          "Path: ${CODEBASE_LOCATION}"
    exit 1
}

add_event "WORKSPACE NAVIGATION" "Successful" \
      "Successfully navigated to workspace" \
      "Path: ${CODEBASE_LOCATION}"

add_event "INITIALIZATION" "Successful" \
      "Task initialization completed" \
      "Target branch: ${TARGET_BRANCH}"

TASK_STATUS=0

TARGET_BRANCH=${TARGET_BRANCH}
logInfoMessage "Target branch is ${TARGET_BRANCH}"
git fetch origin "$TARGET_BRANCH"
add_event "GIT FETCH" "Successful" \
      "Successfully fetched target branch" \
      "Branch: $TARGET_BRANCH"

git merge --no-commit --no-ff "origin/$TARGET_BRANCH" || true

if git diff --name-only --diff-filter=U | grep -q .; then
  logErrorMessage "Merge conflict detected with $TARGET_BRANCH"
  add_event "CONFLICT CHECK" "Failed" \
        "Merge conflicts detected" \
        "Conflicts found with $TARGET_BRANCH"
  git merge --abort
  exit 1
else
  logInfoMessage "No merge conflicts with $TARGET_BRANCH"
  add_event "CONFLICT CHECK" "Successful" \
        "No merge conflicts detected" \
        "Clean merge possible with $TARGET_BRANCH"
  git merge --abort
  exit 0
fi

TASK_STATUS=$?
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
add_event "TASK EXECUTION" "Successful" \
      "Merge conflict check completed" \
      "No conflicts found with $TARGET_BRANCH"
