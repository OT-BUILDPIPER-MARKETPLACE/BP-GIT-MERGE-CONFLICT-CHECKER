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
cd  "${CODEBASE_LOCATION}"

TASK_STATUS=0

TARGET_BRANCH=${TARGET_BRANCH}
logInfoMessage "Target branch is ${TARGET_BRANCH}"
git fetch origin "$TARGET_BRANCH"

git merge --no-commit --no-ff "origin/$TARGET_BRANCH" || true

if git diff --name-only --diff-filter=U | grep -q .; then
  logErrorMessage "Merge conflict detected with $TARGET_BRANCH"
  git merge --abort
  exit 1
else
  logInfoMessage "No merge conflicts with $TARGET_BRANCH"
  git merge --abort
  exit 0
fi

TASK_STATUS=?
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
