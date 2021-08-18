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

mysql:Client dbClient = check new (host = host, user = username, password = password);

service /db on new http:Listener(9092) {
    resource function post .(http:Caller caller, http:Request clientRequest) {
        sql:ExecutionResult|error result = dbClient->execute("CREATE TABLE IF NOT EXISTS " + database_name + "." +
        table_name + "(Id INTEGER NOT NULL AUTO_INCREMENT, Name  VARCHAR(300), " +
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
                result = dbClient->execute("INSERT INTO " + database_name + "." + table_name +
                 "(Name, Category, Price) VALUES (" + "'"+ records[0] + "', '" + records[1] + "', "+ records[2] + ")");
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
    }
}

function getError(http:Caller caller, string msg) {
    http:Response res = new;
    res.statusCode = 500;
    res.setPayload(msg);
    error? result = caller->respond(res);
}
