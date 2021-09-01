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
# Base script for executing jmeter performance test
# ----------------------------------------------------------------------------
set -e

scenario_name=""
concurrent_users=""
payload_flags=""

while getopts "s:u:f:h" opts; do
    case $opts in
    s)
        scenario_name=${OPTARG}
        ;;
    u)
        concurrent_users=${OPTARG}
        ;;
    f)
        payload_flags=${OPTARG}
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

if [[ -z $scenario_name ]]; then
    echo "Please provide the scenario name."
    exit 1
fi

if [[ -z $concurrent_users ]]; then
    echo "Please provide the number of concurrent users."
    exit 1
fi

scriptsDir="/home/bal-admin/ballerina-performance-cloud/tests/"$scenario_name"/scripts"
resultsDir="/home/bal-admin/ballerina-performance-cloud/tests/"$scenario_name"/results"