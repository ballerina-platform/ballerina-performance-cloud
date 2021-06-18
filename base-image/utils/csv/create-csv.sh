#!/bin/bash

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
# Generate final csv
# ----------------------------------------------------------------------------
set -e
if [ "$#" -ne 2 ]; then
  echo "Script expect 2 parameters"
  echo "parameter1 : New summary.csv file"
  echo "parameter2 : Existing summary.csv file to append results"
  exit 1
fi

buildTime=$(date)
echo "CSV modification started"
# Append Date header
sed -i ' 1 s/.*/&,Date/' "${1}"
# Append Date value
sed -i " 2 s/.*/&,${buildTime}/" "${1}"
# Remove total row
sed -i '$ d' "${1}"
echo "CSV modification completed"

echo "Merge csv started ${1} ${2}"
# Merge csv files
cat "${2}" <(tail +2 "${1}") >summary-temp.csv
mv summary-temp.csv "${2}"
echo "Merge csv completed ${1} ${2}"
