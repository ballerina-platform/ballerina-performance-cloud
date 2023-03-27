#!/bin/bash -e
# Copyright 2021 WSO2 Inc. (http://wso2.org)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ----------------------------------------------------------------------------
# Running the Load Test
# ----------------------------------------------------------------------------
set -e

payload_size=${PAYLOAD_SIZE}
branch_name=${BRANCH_NAME}
concurrent_users=${CONCURRENT_USERS}
base_branch=${BASE_BRANCH}

if [[ -z ${REPO_NAME} ]]; then
    echo "Please provide the repo name."
    exit 1
fi

if [[ -z ${SCENARIO_NAME} ]]; then
    echo "Please provide the scenario name."
    exit 1
fi

if [[ -z ${GITHUB_TOKEN} ]]; then
    echo "Please provide the github name."
    exit 1
fi

if [[ -z ${concurrent_users} ]]; then
    echo "Please provide the number of concurrent users."
    exit 1
fi

git clone https://ballerina-bot:"${GITHUB_TOKEN}"@github.com/ballerina-platform/"${REPO_NAME}"
pushd "${REPO_NAME}"

if [[ -z $branch_name ]]; then
    timestamp=$(date +%s -u)
    branch_name="nightly-${SCENARIO_NAME}-${timestamp}"
    if [[ -z $base_branch ]]; then
        git checkout -b "${branch_name}"
    else 
        git checkout -b "${branch_name}" -t "origin/${base_branch}"
    fi
else 
    git checkout ${branch_name}
fi

git config --global user.email "ballerina-bot@ballerina.org"
git config --global user.name "ballerina-bot"
git status
git remote -v
popd

payload_flags=""

if [[ ! -z ${CLUSTER_IP} ]]; then
    echo "${CLUSTER_IP} bal.perf.test" | sudo tee -a /etc/hosts
fi

function executeScript() {
  FILE="${REPO_NAME}"/load-tests/"${SCENARIO_NAME}"/scripts/"${1}"
  if test -f "$FILE"; then
      echo "-------- Executing $1 --------"
      pushd "${REPO_NAME}"/load-tests/"${SCENARIO_NAME}"/scripts/
      chmod +x "${1}"
       . ./"${1}" -r "${REPO_NAME}" -s "${SCENARIO_NAME}" -u "${concurrent_users}" -f "$payload_flags" # The use of a dot before the command ensures 
       # that the variable persists even after the script ${1} has completed execution.
      popd
      echo "-------- $1 executed --------"
  fi
}

function generatePayload() {
    if [[ $1 != "0" ]]; then
        echo "--------Generating ${payload_size} Payload--------"
        generate-payloads.sh -p array -s "${payload_size}"
        payload_flags+=" -Jresponse_size=${payload_size} -Jpayload=$(pwd)/${payload_size}""B.json"
        echo payload_flags
        echo "--------End of generating payload--------"
    fi
}

executeScript "pre_run.sh"
generatePayload "${payload_size}"

echo "--------Running test ${SCENARIO_NAME}--------"
pushd "${REPO_NAME}"/load-tests/"${SCENARIO_NAME}"/scripts/
chmod +x run.sh
./run.sh -r "${REPO_NAME}" -s "${SCENARIO_NAME}" -u "${concurrent_users}" -f "$payload_flags"
concurrent_users=$(grep "users=" jmeter.log | sed -e 's/.*=//')
popd
echo "--------End test--------"

POST_RUN_FILE="${REPO_NAME}"/load-tests/"${SCENARIO_NAME}"/scripts/post_run.sh
if test -f "$POST_RUN_FILE"; then
  executeScript "post_run.sh"
fi

if [[ "$FORCE_ENABLE_JMETER_PROCESSING" == "true" ]] || test ! -f "$POST_RUN_FILE"; then
  echo "--------Processing Results--------"
  pushd "${REPO_NAME}"/load-tests/"${SCENARIO_NAME}"/results/
  echo "--------Splitting Results--------"
  jtl-splitter.sh -- -f original.jtl -t 120 -u SECONDS -s
  ls -ltr
  echo "--------Splitting Completed--------"

  echo "--------Generating CSV--------"
  sudo chmod +x $JMETER_HOME/bin/JMeterPluginsCMD.sh
  JMeterPluginsCMD.sh --generate-csv temp_summary.csv --input-jtl original-measurement.jtl --plugin-type AggregateReport
  echo "--------CSV generated--------"

  echo "--------Merge CSV--------"
  create-csv.sh temp_summary.csv /home/ballerina/"${REPO_NAME}"/load-tests/"${SCENARIO_NAME}"/results/summary.csv "${payload_size}" "${concurrent_users}"
  echo "--------CSV merged--------"
  popd
fi

if [[ -z ${SPACE_ID} || -z ${MESSAGE_KEY} || -z ${CHAT_TOKEN} ]]; then
    echo "--- Notification Service skipped as configurations not set"
else 
    echo "--------Starting Notification Service--------"
    # docker run -v /home/ballerina/"${REPO_NAME}"/load-tests/"${SCENARIO_NAME}"/results/:/summary -e SPACE_ID="${SPACE_ID}" -e MESSAGE_KEY="${MESSAGE_KEY}" -e CHAT_TOKEN="${CHAT_TOKEN}" -e SCENARIO_NAME="${SCENARIO_NAME}" ballerina/chat_notifications
    echo "--------Notification Service executed--------"
fi

if [[ ! -z ${DISPATCH_TYPE} ]]; then
    pushd "${REPO_NAME}"/load-tests/"${SCENARIO_NAME}"/results/
    sudo mkdir /results/"${SCENARIO_NAME}"
    sed -n '$p' summary.csv | sudo tee /results/"${SCENARIO_NAME}"/summary.csv
    popd
else
    echo "--------Committing CSV--------"
    pushd "${REPO_NAME}"
    git clean -xfd
    git add load-tests/"${SCENARIO_NAME}"/results/summary.csv
    git commit -m "Update ${SCENARIO_NAME} test results on $(date)"
    git push origin "${branch_name}"
    popd
    echo "--------CSV committed--------"
    echo "--------Results processed--------"
fi
