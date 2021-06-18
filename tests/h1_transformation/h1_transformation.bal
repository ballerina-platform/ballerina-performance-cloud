import ballerina/http;
import ballerina/log;
import ballerina/xmldata;

listener http:Listener securedEP = new(9090, {
    secureSocket:  {
        key: {
            path: "./security/ballerinaKeystore.p12",
            password: "ballerina"
        }
    }
});

final http:Client nettyEP = check new("https://netty:8688", {
    secureSocket: {
        cert: {
            path: "./security/ballerinaTruststore.p12",
            password: "ballerina"
        },
        verifyHostName: false
    }
});

service /transform on securedEP {
    resource function post .(http:Caller caller, http:Request req) {
        json|error payload = req.getJsonPayload();
        if (payload is json) {
            xml|xmldata:Error? xmlPayload = xmldata:fromJson(payload);
            if (xmlPayload is xml) {
                http:Request clinetreq = new;
                clinetreq.setXmlPayload(xmlPayload);
                http:Response|http:ClientError response = nettyEP->post("/service/EchoService", clinetreq);
                if (response is http:Response) {
                    error? result = caller->respond(response);
                } else {
                    log:printError("Error at h1_transformation", 'error = response);
                    http:Response res = new;
                    res.statusCode = 500;
                    res.setPayload(response.message());
                    error? result = caller->respond(res);
                }
            } else if (xmlPayload is xmldata:Error) {
                log:printError("Error at h1_transformation", 'error = xmlPayload);
                http:Response res = new;
                res.statusCode = 400;
                res.setPayload(xmlPayload.message());
                error? result = caller->respond(res);
            }
        } else {
            log:printError("Error at h1_transformation", 'error = payload);
            http:Response res = new;
            res.statusCode = 400;
            res.setPayload(payload.message());
            error? result = caller->respond(res);
        }
    }
}
