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
    resource function post .(http:Caller caller, http:Request clientRequest) {
        foreach string[] records in values {
            sql:ExecutionResult|error result = dbClient->execute("INSERT INTO " + database_name + "." + table_name +
             "(Name, Category, Price) VALUES (" + "'"+ records[0] + "', '" + records[1] + "', "+ records[2] + ")");
            if result is error {
                log:printError("Error at db_insertion", 'error = result);
                getError(caller, result.message());
            }
        }
        http:Response res = new;
        res.statusCode = 200;
        res.setJsonPayload("Records inserted succesfully");
        error? output = caller->respond(res);
    }
}

function getError(http:Caller caller, string msg) {
    http:Response res = new;
    res.statusCode = 500;
    res.setJsonPayload(msg);
    error? result = caller->respond(res);
}
