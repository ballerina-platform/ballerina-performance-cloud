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

import ballerina/http;
import ballerina/log;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;
import ballerina/sql;

configurable string host = ?;
configurable string username = ?;
configurable string password = ?;
configurable int port = ?;

mysql:Client dbClient = check new (host = host, user = username, password = password);

service /db on new http:Listener(9092) {
    resource function get .() returns string|error {
        sql:ParameterizedQuery query = `SELECT COUNT(*) AS total FROM petdb.pet`;
        stream<record {}, error?> resultStream = dbClient->query(query);

        record {|record {} value;|}|error? result = resultStream.next();
        check resultStream.close();
        string msg = "No of records: ";
        if result is error {
            log:printError("Error at db_select", 'error = result);
            return result;
        } else if result is record {|record {} value;|} {
            log:printInfo(result.value["total"].toString());
            return result.value["total"].toString();
        } else {
            return "";
        }
    }
}
