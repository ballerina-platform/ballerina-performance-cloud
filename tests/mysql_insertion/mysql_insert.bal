import ballerina/io;
import ballerina/http;
import ballerina/log;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;
import ballerina/regex;
import ballerina/sql;

configurable string host = ?;
configurable string username = ?;
configurable string password = ?;
configurable string database_name = ?;
configurable int port = ?;
configurable string table_name = ?;

service /db on new http:Listener(9092) {
    resource function post .(http:Caller caller, http:Request clientRequest) {
        mysql:Client|error dbClient = new (host = host, user = username, password = password,
                                           database = database_name, port = port);
        if (dbClient is mysql:Client) {
            sql:ExecutionResult|error result = dbClient->execute("DROP TABLE IF EXISTS " + table_name);
            if result is error {
                log:printError("Error at db_insertion", 'error = result);
                getError(caller, result.message());
            }
            result = dbClient->execute("CREATE TABLE " + table_name +
                                        "(Id INTEGER NOT NULL AUTO_INCREMENT, Name  VARCHAR(300), " +
                                        "Category VARCHAR(300), Price INTEGER, PRIMARY KEY(Id))");
            if result is error {
                log:printError("Error at db_insertion", 'error = result);
                getError(caller, result.message());
            }
            string[]|error values = io:fileReadLines("./data/data.csv");
            if values is error {
                log:printError("Error at db_insertion", 'error = values);
                getError(caller, values.message());
            } else {
                foreach string value in values {
                    string[] records = regex:split(value, ",");
                    result = dbClient->execute("INSERT INTO " + table_name + "(Id, Name, Category, Price) VALUES (" +
                    records[0] + ",' " + records[1] + "',' " + records[2] + "', "+ records[3] + ")");
                    if result is error {
                        log:printError("Error at db_insertion", 'error = result);
                        getError(caller, result.message());
                    }
                }
            }
            http:Response res = new;
            res.statusCode = 200;
            res.setPayload("Records inserted succesfully");
            error? output = caller->respond(res);
        } else {
            getError(caller, dbClient.message());
        }
    }
}

function getError(http:Caller caller, string msg) {
    http:Response res = new;
    res.statusCode = 500;
    res.setPayload(msg);
    error? result = caller->respond(res);
}
