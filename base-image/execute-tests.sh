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
REPO_NAME="ballerina-performance-cloud"

(
  cd ~/
  git clone https://github.com/ballerina-platform/${REPO_NAME}
)
echo "$1 bal.perf.test" | sudo tee -a /etc/hosts

echo "--------Running test ${2}--------"
pushd ~/${REPO_NAME}/tests/"${2}"/scripts/
./run.sh "${2}"
popd
echo "--------End test--------"

echo "--------Processing Results--------"
pushd ~/${REPO_NAME}/tests/"${2}"/results/
echo "--------Splitting Results--------"
jtl-splitter.sh -- -f original.jtl -t 300 -u SECONDS -s
ls -ltr
echo "--------Splitting Completed--------"

echo "--------Generating CSV--------"
JMeterPluginsCMD.sh --generate-csv summary.csv --input-jtl original-measurement.jtl --plugin-type AggregateReport
echo "--------CSV generated--------"

echo "--------Merge csv--------"
create-csv.sh summary.csv ~/${REPO_NAME}/summary/"${2}".csv
echo "--------CSV merged--------"
popd
echo "--------Results processed--------"
