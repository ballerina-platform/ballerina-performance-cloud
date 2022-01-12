FROM ubuntu:18.04
LABEL maintainer="dev@ballerina.io"

RUN apt update -y && apt install curl wget default-jre unzip jq git sudo -y

SHELL ["/bin/bash", "-c"]

COPY configure-jmeter.sh /

RUN ./configure-jmeter.sh -i /opt/ -d

ENV PATH=$PATH:/opt/apache-jmeter-5.4/bin/
ENV JMETER_HOME=/opt/apache-jmeter-5.4

CMD jmeter
