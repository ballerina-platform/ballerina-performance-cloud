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
configurable string tablename = ?;
configurable string path = ?;


service /db on new http:Listener(9092) {
    resource function post insertData() returns string|error {
        mysql:Client dbClient = check new (host = host, user = username, password = password,
                                           database = database_name, port = port);
        _ = check dbClient->execute("DROP TABLE IF EXISTS " + tablename);
        _ = check dbClient->execute("CREATE TABLE " + tablename +
                                    "(Id INTEGER NOT NULL AUTO_INCREMENT, Name  VARCHAR(300), Category VARCHAR(300), " +
                                    "Price INTEGER, PRIMARY KEY(Id))");
        string[] records = check io:fileReadLines(path);
        foreach string value in values {
            string[] records = regex:split(value, ",");
            var e1 = check dbClient->execute("INSERT INTO " + tablename + "(Id, Name, Category, Price) VALUES (" +
            records[0] + ",' " + records[1] + "',' " + records[2] + "', "+ records[3] + ")");
        }
        return "Records inserted succesfully";
    }
}
