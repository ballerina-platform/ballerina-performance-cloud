import ballerina/io;
import ballerina/http;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;
import ballerina/regex;

configurable string host = ?;
configurable string username = ?;
configurable string password = ?;
configurable string database_name = ?;
configurable int port = ?;
configurable string table_name = ?;

service /db on new http:Listener(9092) {
    resource function post select() returns string|error {
        mysql:Client dbClient = check new (host = host, user = username, password = password,
                                           database = database_name, port = port);
        stream<record {}, error?> resultStream =
                dbClient->query("SELECT COUNT(*) AS total FROM " + table_name);

        record {|record {} value;|}|error? result = resultStream.next();
        string output = "Total rows in customer table : ";
        if result is record {|record {} value;|} {
             output += result.value["total"]);
        }
        error? er = resultStream2.close();
        return output;
    }
}
