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
    resource function post update/[int id]/[int price]() returns int|error {
        mysql:Client dbClient = check new (host = host, user = username, password = password,
                                           database = database_name, port = port);
        string updateQuery = "UPDATE " + table_name + " SET Price = " + price.toString() + " where id = " +
        id.toString();

        sql:ExecutionResult result = check dbClient->execute(updateQuery);
        int? affectedRowCount = result?.affectedRowCount;
        if (affectedRowCount is int) {
            return affectedRowCount;
        }
        return 0;
    }
}
