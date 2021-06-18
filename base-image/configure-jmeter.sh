#!/bin/bash -e
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
# Installation script for setting up Apache JMeter
# ----------------------------------------------------------------------------

script_dir=$(dirname "$0")
jmeter_dist=""
installation_dir=""
download=false
# JMeter Plugins
declare -a plugins

function usage() {
    echo ""
    echo "Usage: "
    echo "$0 -i <installation_dir> [-f <jmeter_dist>] [-d] [-p <jmeter_plugin_name>] [-h]"
    echo ""
    echo "-i: Apache JMeter installation directory."
    echo "-f: Apache JMeter tgz distribution."
    echo "-d: Download Apache JMeter from web."
    echo "-p: The name of the JMeter Plugin to install. You can provide multiple names."
    echo "-h: Display this help and exit."
    echo ""
}

while getopts "df:i:p:h" opts; do
    case $opts in
    d)
        download=true
        ;;
    f)
        jmeter_dist=${OPTARG}
        ;;
    i)
        installation_dir=${OPTARG}
        ;;
    p)
        plugins+=("${OPTARG}")
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

if [[ ! -d $installation_dir ]]; then
    echo "Please provide the JMeter installation direcory."
    exit 1
fi

if [ "$download" = true ]; then
    if [[ ! -z $jmeter_dist ]]; then
        echo "Do not specify JMeter distribution file with download option."
        exit 1
    fi
    jmeter_version="4.0"
    jmeter_dist="apache-jmeter-${jmeter_version}.tgz"
    jmeter_download_url="https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${jmeter_version}.tgz"
    if [[ ! -f $jmeter_dist ]]; then
        # Download JMeter
        echo "Downloading JMeter distribution"
        if ! wget -q $jmeter_download_url -O $jmeter_dist; then
            echo "Failed to download JMeter!"
            exit 1
        fi
    fi
    # Verify JMeter
    echo "Verifying JMeter distribution"
    curl -s ${jmeter_download_url}.sha512 | sha512sum -c
fi

if [[ ! -f $jmeter_dist ]]; then
    echo "Please specify the JMeter distribution file (*.tgz)"
    exit 1
fi

if [[ ! $jmeter_dist =~ ^.*\.tgz$ ]]; then
    echo "Please provide the JMeter tgz distribution file (*.tgz)"
    exit 1
fi

# Install following plugins to generate AggregateReport from command line.
# For example:
# JMeterPluginsCMD.sh --generate-csv test.csv --input-jtl results.jtl --plugin-type AggregateReport
plugins+=("jpgc-cmd" "jpgc-synthesis")

# Extract JMeter Distribution
dirname=$(tar -tf $jmeter_dist | head -1 | sed -e 's@/.*@@')

installation_dir=$(realpath $installation_dir)

extracted_dirname=$installation_dir"/"$dirname

if [[ ! -d $extracted_dirname ]]; then
    echo "Extracting $jmeter_dist to $installation_dir"
    tar -xof $jmeter_dist -C $installation_dir
    echo "JMeter is extracted to $extracted_dirname"
else
    echo "JMeter is already extracted to $extracted_dirname"
fi

properties_file=$script_dir/user.properties

# echo "Copying $properties_file file to $extracted_dirname/bin"
# cp $properties_file $extracted_dirname/bin

if grep -q "export JMETER_HOME=.*" $HOME/.bashrc; then
    sed -i "s|export JMETER_HOME=.*|export JMETER_HOME=$extracted_dirname|" $HOME/.bashrc
else
    echo "export JMETER_HOME=$extracted_dirname" >>$HOME/.bashrc
fi
source $HOME/.bashrc

echo "Installing JMeter Plugins Manager"
# Install JMeter Plugins Manager. Refer https://jmeter-plugins.org/wiki/PluginsManagerAutomated/
wget_useragent="Linux Server"
plugins_manager_output_file=jmeter-plugins-manager.jar

# Download plugins manager JAR file

if ! ls $extracted_dirname/lib/ext/jmeter-plugins-manager*.jar 1>/dev/null 2>&1; then
    wget -q -U "${wget_useragent}" https://jmeter-plugins.org/get/ -O /tmp/${plugins_manager_output_file}
    cp /tmp/$plugins_manager_output_file $extracted_dirname/lib/ext/
fi

# Run Command Line Installer
tmp=($extracted_dirname/lib/ext/jmeter-plugins-manager*.jar)
plugin_manager_jar="${tmp[0]}"

java -cp $plugin_manager_jar org.jmeterplugins.repository.PluginManagerCMDInstaller

plugins_manager_cmd=$extracted_dirname/bin/PluginsManagerCMD.sh

if [[ ! -f $plugins_manager_cmd ]]; then
    echo "Plugins Manager Command Line Installer is not available!"
    exit 1
fi

cmdrunner_version=$(grep -o 'cmdrunner-\(.*\)\.jar' $plugins_manager_cmd | sed -nE 's/cmdrunner-(.*)\.jar/\1/p')
cmdrunner_jar=cmdrunner-${cmdrunner_version}.jar

if [[ ! -f $extracted_dirname/lib/${cmdrunner_jar} ]]; then
    echo "Downloading ${cmdrunner_jar}"
    wget -q -U "${wget_useragent}" http://search.maven.org/remotecontent?filepath=kg/apc/cmdrunner/${cmdrunner_version}/${cmdrunner_jar} -O /tmp/${cmdrunner_jar}
    cp /tmp/${cmdrunner_jar} $extracted_dirname/lib/
fi

PluginsManagerCMD=$plugins_manager_cmd

echo "Checking for plugin upgrades"
upgrade_response="$(echo "$($PluginsManagerCMD upgrades)" | tail -1)"

if [[ "$upgrade_response" =~ nothing ]]; then
    echo "No upgrades"
else
    echo "Installing upgrades"
    upgrades=$(tr -d '[:space:]' <<<"$upgrade_response")
    upgrades=$(sed -e 's/^\[//' -e 's/\]$//' <<<"$upgrades")
    # Install Upgrades
    $PluginsManagerCMD install "$upgrades"
fi

for plugin in "${plugins[@]}"; do
    echo "Installing $plugin plugin"
    $PluginsManagerCMD install $plugin
done

# Set cmdrunner version in JMeterPluginsCMD.sh
sed -i "s/cmdrunner-.*\.jar/$cmdrunner_jar/g" $extracted_dirname/bin/JMeterPluginsCMD.sh

export PATH=$PATH:/base-image/apache-jmeter-4.0/bin/
echo 'export PATH=$PATH:/base-image/apache-jmeter-4.0/bin/' | sudo tee -a /etc/profile.d/10-perf-vm.sh
