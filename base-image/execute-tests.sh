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

cluster_ip=""
scenario_name=""
github_token=""
payload_size="0"
concurrent_users=""
space_id=""
message_key=""
chat_token=""
repo_name=""
function usage() {
    echo ""
    echo "Usage: "
    echo "$0 [-c <cluster_ip>] [-s scenario_name] [-t github_token] [-p payload_size] [-u concurrent_users] [-h]"
    echo ""
    echo "-r: Name of the repo containing tests"
    echo "-c: Kubernetes cluster IP"
    echo "-s: Test scenario name"
    echo "-t: Github token for the repository"
    echo "-p: Payload size"
    echo "-u: Concurrent users for the test"
    echo "-i: Space ID of the chat room"
    echo "-m: Message Key of the chat"
    echo "-a: Chat token"
    echo ""
}

while getopts "r:c:s:t:p:u:i:m:a:h" opts; do
    case $opts in
    r)
        repo_name=${OPTARG}
        ;;
    c)
        cluster_ip=${OPTARG}
        ;;
    s)
        scenario_name=${OPTARG}
        ;;
    t)
        github_token=${OPTARG}
        ;;
    p)
        payload_size=${OPTARG}
        ;;
    u)
        concurrent_users=${OPTARG}
        ;;
    i)
        space_id=${OPTARG}
        ;;
    m)
        message_key=${OPTARG}
        ;;
    a)
        chat_token=${OPTARG}
        ;;
    h)
        usage
        exit 0
        ;;
    \?)
        usage
        exit 1
        ;;
    esac
done

if [[ -z $repo_name ]]; then
    echo "Please provide the repo name."
    exit 1
fi

if [[ -z $cluster_ip ]]; then
    echo "Please provide the cluster ip."
    exit 1
fi

if [[ -z $scenario_name ]]; then
    echo "Please provide the scenario name."
    exit 1
fi

if [[ -z $github_token ]]; then
    echo "Please provide the scenario name."
    exit 1
fi

if [[ -z $concurrent_users ]]; then
    echo "Please provide the number of concurrent users."
    exit 1
fi

timestamp=$(date +%s)
branch_name="nightly-$scenario_name-${timestamp}"
git clone https://ballerina-bot:"$github_token"@github.com/ballerina-platform/"${repo_name}"
pushd "${repo_name}"
git checkout -b "${branch_name}"
git config --global user.email "ballerina-bot@ballerina.org"
git config --global user.name "ballerina-bot"
git status
git remote -v
popd

payload_flags=""

echo "$cluster_ip bal.perf.test" | sudo tee -a /etc/hosts

function executeScript() {
  FILE="${repo_name}"/load-tests/"$scenario_name"/scripts/"${1}"
  if test -f "$FILE"; then
      echo "-------- Executing $1 --------"
      pushd "${repo_name}"/load-tests/"${scenario_name}"/scripts/
      chmod +x "${1}"
      sudo ./"${1}"
      echo "-------- $1 executed --------"
  fi
}

function generatePayload() {
    if [[ $1 != "0" ]]; then
        echo "--------Generating $payload_size Payload--------"
        generate-payloads.sh -p array -s "$payload_size"
        payload_flags+=" -Jresponse_size=$payload_size -Jpayload=$(pwd)/$payload_size""B.json"
        echo payload_flags
        echo "--------End of generating payload--------"
    fi
}

executeScript "pre_run.sh"
generatePayload "$payload_size"

echo "--------Running test $scenario_name--------"
pushd "${repo_name}"/load-tests/"$scenario_name"/scripts/
chmod +x run.sh
./run.sh -r "$repo_name" -s "$scenario_name" -u "$concurrent_users" -f "$payload_flags"
popd
echo "--------End test--------"

POST_RUN_FILE="${repo_name}"/load-tests/"$scenario_name"/scripts/post_run.sh
if test -f "$POST_RUN_FILE"; then
  executeScript "post_run.sh"
else
  echo "--------Processing Results--------"
  pushd "${repo_name}"/load-tests/"$scenario_name"/results/
  echo "--------Splitting Results--------"
  jtl-splitter.sh -- -f original.jtl -t 120 -u SECONDS -s
  ls -ltr
  echo "--------Splitting Completed--------"

  echo "--------Generating CSV--------"
  JMeterPluginsCMD.sh --generate-csv temp_summary.csv --input-jtl original-measurement.jtl --plugin-type AggregateReport
  echo "--------CSV generated--------"

  echo "--------Merge CSV--------"
  create-csv.sh temp_summary.csv ~/"${repo_name}"/load-tests/"$scenario_name"/results/summary.csv "$payload_size" "$concurrent_users"
  echo "--------CSV merged--------"
fi

if [[ -z $space_id || -z $message_key || -z $chat_token ]]; then
    echo "--- Notification Service skipped as configurations not set"
else 
    echo "--------Starting Notification Service--------"
    sudo docker run -v ~/"${repo_name}"/load-tests/"$scenario_name"/results/:/summary -e SPACE_ID="$space_id" -e MESSAGE_KEY="$message_key" -e CHAT_TOKEN="$chat_token" -e SCENARIO_NAME="$scenario_name" ballerina/chat_notifications
    echo "--------Notification Service executed--------"
fi

popd

echo "--------Committing CSV--------"
pushd "${repo_name}"
git clean -xfd
git add load-tests/"$scenario_name"/results/
git commit -m "Update $scenario_name test results on $(date)"
git push origin "${branch_name}"
popd
echo "--------CSV committed--------"
echo "--------Results processed--------"
