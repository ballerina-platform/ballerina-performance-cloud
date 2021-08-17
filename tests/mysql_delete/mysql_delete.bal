import ballerina/http;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;
import ballerina/sql;

configurable string host = ?;
configurable string username = ?;
configurable string password = ?;
configurable string database_name = ?;
configurable int port = ?;
configurable string table_name = ?;

service /db on new http:Listener(9092) {
    resource function post delete/[int id]() returns int|error {
        mysql:Client dbClient = check new (host = host, user = username, password = password,
                                           database = database_name, port = port);

        string deleteQuery = "DELETE FROM pet WHERE id = " + id.toString();

        sql:ExecutionResult result = check dbClient->execute(deleteQuery);
        int? deleteRowCount = result?.affectedRowCount;
        if (deleteRowCount is int) {
            return deleteRowCount;
        }
        return 0;
    }
}