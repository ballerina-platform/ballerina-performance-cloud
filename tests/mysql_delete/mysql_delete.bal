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
int id = 1;
int count = 0;

mysql:Client dbClient = check new (host = host, user = username, password = password);

service /db on new http:Listener(9092) {
    resource function post .(http:Caller caller, http:Request clientRequest) {
        string deleteQuery = "DELETE FROM " + database_name + "." + table_name + " WHERE id = " + id.toString();

        sql:ExecutionResult|error result = dbClient->execute(deleteQuery);
        if result is error {
            log:printError("Error at db_insertion", 'error = result);
            getError(caller, result.message());
        } else {
            int? deleteRowCount = result?.affectedRowCount;
            if (deleteRowCount is int) {
                count = deleteRowCount;
                id += 1;
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
