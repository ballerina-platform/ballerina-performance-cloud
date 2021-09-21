// Copyright (c) 2021 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/io;
import ballerina/time;
import ballerina/file;
import ballerina/http;
import ballerina/os;
import ballerina/log;

const float avgRateLimit = 10.0;
const float tpsRateLimit = 10.0;

final http:Client chatWebhookAPI = check new ("https://chat.googleapis.com");

type EnvError distinct error;

public function main() returns error? {
    string scenarioName = os:getEnv("SCENARIO_NAME");
    if (scenarioName == "") {
        return error EnvError("Env variable SCENARIO_NAME not found");
    }
    log:printInfo("Started running notification service for " + scenarioName);
    log:printInfo("Response Average threshold " + avgRateLimit.toString() + "%");
    log:printInfo("TPS threshold " + tpsRateLimit.toString() + "%");
    string absPath = "/summary/" + scenarioName + ".csv";
    string baseName = check file:basename(absPath);

    string[][] listResult = check io:fileReadCsv(absPath);
    if (listResult.length() <= 1) {
        log:printInfo("Only contains the header, skipping");
        return;
    }
    string[] lastEntry = listResult[listResult.length() - 1];
    log:printInfo("Newly added row : " + lastEntry.toString());
    string[] beforeLastEntry = getBeforeLastEntry(listResult);
    log:printInfo("Comparission row : " + lastEntry.toString());

    string toDate = time:utcToString([check int:fromString(lastEntry[13])]);
    string fromDate = time:utcToString([check int:fromString(beforeLastEntry[13])]);

    //Average
    int newAverage = check int:fromString(lastEntry[2]);
    int oldAverage = check int:fromString(beforeLastEntry[2]);
    log:printInfo("new avg of " + scenarioName + " " + newAverage.toString());
    log:printInfo("old avg of " + scenarioName + " " + oldAverage.toString());
    float avgPercentage = ((<float>newAverage - <float>oldAverage) * 100.0 / <float>oldAverage);
    log:printInfo("Average Delta " + avgPercentage.toString());
    if (avgPercentage > avgRateLimit) {
        log:printInfo("Sending Notification");
        check sendNotification("Average response time increased by " + avgPercentage.toString() + "% for the `" + scenarioName + "` sample. \n" + 
        "Click here for the list of PRs merged within the time period " + getGithubSearchUrl(fromDate, toDate));
    } else {
        log:printInfo("Notification send skipped as delta threshold is not reached.");
    }

    //TPS
    float newTps = check float:fromString(lastEntry[10]);
    float oldTps = check float:fromString(beforeLastEntry[10]);
    log:printInfo("new tps of " + scenarioName + " " + newTps.toString());
    log:printInfo("old tps of " + scenarioName + " " + oldTps.toString());
    float tpsPercentage = ((<float>oldTps - <float>newTps) * 100.0 / <float>oldTps);
    log:printInfo("TPS Delta " + tpsPercentage.toString());
    if (tpsPercentage > tpsRateLimit) {
        log:printInfo("Sending Notification");
        check sendNotification("Throughput decreased by " + tpsPercentage.toString() + "% for the `" + scenarioName + "` sample. \n" + 
        "Click here for the list of PRs merged within the time period " + getGithubSearchUrl(fromDate, toDate));
    } else {
        log:printInfo("Notification send skipped as delta threshold is not reached.");

    }
}

function getBeforeLastEntry(string[][] entries) returns string[] {
    string[] lastEntry = entries[entries.length() - 1];
    string payload = lastEntry[14];
    string users = lastEntry[15];
    string[][] reversedEntries = entries.reverse();
    _ = reversedEntries.remove(0);
    foreach string[] row in reversedEntries {
        string newEntryPayload = row[14];
        string newEntryUsers = row[15];
        if (newEntryPayload == payload && newEntryUsers == users) {
            return row;
        }
    }
    return lastEntry;
}

function sendNotification(string message) returns error? {
    string spaceId = os:getEnv("SPACE_ID");
    if (spaceId == "") {
        return error EnvError("Env variable SPACE_ID not found");
    }
    string messageKey = os:getEnv("MESSAGE_KEY");
    if (messageKey == "") {
        return error EnvError("Env variable MESSAGE_KEY not found");
    }
    string token = os:getEnv("CHAT_TOKEN");
    if (token == "") {
        return error EnvError("Env variable CHAT_TOKEN not found");
    }

    json requestBody = {
        "text": message
    };

    http:Response resp = check chatWebhookAPI->post("/v1/spaces/" + spaceId + "/messages?key=" + messageKey + "token=" + token, requestBody);
    if (resp.statusCode == 200) {
        log:printInfo("Notification sent");
    } else {
        log:printWarn("Notification request failed " + resp.statusCode.toString());
    }
}

function getGithubSearchUrl(string fromDate, string toDate) returns string {
    return "https://github.com/pulls?q=is%3Apr+user%3Aballerina-platform+archived%3Afalse+merged%3A" + fromDate + ".." + toDate;
}
