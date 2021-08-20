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
string id = "2";
string price = "1400";
int count = 0;

mysql:Client dbClient = check new (host = host, user = username, password = password);

service /db on new http:Listener(9092) {
    resource function post .(http:Caller caller, http:Request clientRequest) {
        string updateQuery = "UPDATE " + database_name + "." + table_name + " SET Price = " + price +
         " where id = " + id;

        sql:ExecutionResult|error result = dbClient->execute(updateQuery);
        if result is error {
            log:printError("Error at db_insertion", 'error = result);
            getError(caller, result.message());
        } else {
            int? deleteRowCount = result?.affectedRowCount;
            if (deleteRowCount is int) {
                count = deleteRowCount;
            }
        }
        http:Response res = new;
        res.statusCode = 200;
        res.setJsonPayload("Effected row:" + count.toString());
        error? output = caller->respond(res);
    }
}

function getError(http:Caller caller, string msg) {
    http:Response res = new;
    res.statusCode = 500;
    res.setJsonPayload(msg);
    error? result = caller->respond(res);
}
