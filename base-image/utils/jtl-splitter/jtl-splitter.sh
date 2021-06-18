#!/bin/bash
# Copyright 2017 WSO2 Inc. (http://wso2.org)
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
# Split JTL file
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
default_heap_size="1g"
heap_size="$default_heap_size"

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 [-m <heap_size>] [-h] -- [jtl_splitter_flags]"
    echo ""
    echo "-m: The heap memory size. Default: $default_heap_size"
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "m:h" opts; do
    case $opts in
    m)
        heap_size=${OPTARG}
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
shift "$((OPTIND - 1))"

jtl_splitter_flags="$@"

if [[ -z $heap_size ]]; then
    echo "Please specify the heap size."
    exit 1
fi

java -Xms${heap_size} -Xmx${heap_size}  -jar $script_dir/jtl-splitter-0.4.6-SNAPSHOT.jar $jtl_splitter_flags
