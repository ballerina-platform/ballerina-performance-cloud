import ballerina/http;
import ballerina/log;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

configurable string host = ?;
configurable string username = ?;
configurable string password = ?;
configurable string database_name = ?;
configurable int port = ?;
configurable string table_name = ?;

mysql:Client dbClient = check new (host = host, user = username, password = password);

service /db on new http:Listener(9092) {
    resource function get .(http:Caller caller, http:Request clientRequest) {
        stream<record {}, error?> resultStream =
                dbClient->query("SELECT COUNT(*) AS total FROM " + database_name + "." + table_name);

        record {|record {} value;|}|error? result = resultStream.next();
        string msg = "No of records: ";
        if result is error {
            log:printError("Error at db_insertion", 'error = result);
            getError(caller, result.message());
        } else if result is record {|record {} value;|} {
            msg += result.value["total"].toString();
        }
        error? er = resultStream.close();
        http:Response res = new;
        res.statusCode = 200;
        res.setJsonPayload(msg);
        error? output = caller->respond(res);
    }
}

function getError(http:Caller caller, string msg) {
    http:Response res = new;
    res.statusCode = 500;
    res.setJsonPayload(msg);
    error? result = caller->respond(res);
}
