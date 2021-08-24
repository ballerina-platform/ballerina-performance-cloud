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
configurable string database_name = ?;
configurable int port = ?;
configurable string table_name = ?;

string[][] values = [["Bella","Cat","3000"], ["Lucy","Cat","1000"], ["Emma","Cat","1500"], ["Bob","Cat","1400"],
                     ["Moose","Cat","2500"], ["Tigger","Cat","1700"], ["Levi","Dog","1200"], ["Benny","Dog","1500"],
                     ["Joey","Dog","1100"], ["Harry","Dog","1200"], ["Thor","Dog","1800"], ["rusty","Dog","1200"],
                     ["Bo","Dog","1600"], ["Teddy","Dog","2500"], ["Bear","Dog","2500"]];
mysql:Client dbClient = check new (host = host, user = username, password = password);

service /db on new http:Listener(9092) {
    resource function post .() returns string|error {
        foreach string[] records in values {
            sql:ParameterizedQuery query = `INSERT INTO petdb.pet (Name, Category, Price)
            VALUES (${records[0]}, ${records[1]}, ${records[2]})`;
            sql:ExecutionResult|error result = dbClient->execute(query);
            if result is error {
                log:printError("Error at db_insert", 'error = result);
                return result;
            }
        }
        return "Records inserted succesfully";
    }
}
