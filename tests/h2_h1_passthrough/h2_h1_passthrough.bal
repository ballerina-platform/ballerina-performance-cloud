import ballerina/http;
import ballerina/log;

listener http:Listener securedEP = new(9090, {
    httpVersion: "2.0",
    secureSocket: {
        key: {
            path: "./security/ballerinaKeystore.p12",
            password: "ballerina"
        }
    }
});

final http:Client nettyEP = check new("https://netty:8688", {
    secureSocket:  {
        cert: {
            path: "./security/ballerinaTruststore.p12",
            password: "ballerina"
        },
        verifyHostName: false
    }
});

service /passthrough on securedEP {
    resource function post .(http:Caller caller, http:Request clientRequest) {
        http:Response|http:ClientError response = nettyEP->forward("/service/EchoService", clientRequest);
        if (response is http:Response) {
            error? result = caller->respond(response);
        } else {
            log:printError("Error at h2_h1_passthrough", 'error = response);
            http:Response res = new;
            res.statusCode = 500;
            res.setPayload(response.message());
            error? result = caller->respond(res);
        }
    }
}
