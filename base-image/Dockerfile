FROM ballerina/jmeter_container:latest
LABEL maintainer="dev@ballerina.io"

RUN apt update -y && apt install bc -y

RUN useradd -m ballerina && echo "ballerina:ballerina" | chpasswd && adduser ballerina sudo
WORKDIR /home/ballerina
RUN echo "ballerina ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER ballerina

SHELL ["/bin/bash", "-c"]

COPY --chown=ballerina execute-tests.sh /home/ballerina/setup/ 
COPY --chown=ballerina base-scenario.sh /home/ballerina/setup/ 
COPY --chown=ballerina utils /home/ballerina/setup/utils/

ENV PATH=$PATH:/home/ballerina/setup/utils/jtl-splitter/
ENV PATH=$PATH:/home/ballerina/setup/utils/payloads/
ENV PATH=$PATH:/home/ballerina/setup/utils/csv/
ENV PATH=$PATH:/home/ballerina/setup/

ENV REPO_NAME=""
ENV CLUSTER_IP=""
ENV SCENARIO_NAME=""
ENV GITHUB_TOKEN=""
ENV PAYLOAD_SIZE="0"
ENV SPACE_ID=""
ENV MESSAGE_KEY=""
ENV CHAT_TOKEN=""
ENV DISPATCH_TYPE=""
ENV BRANCH_NAME=""
ENV CONCURRENT_USERS="1"
ENV VERSION=""

CMD bash /home/ballerina/setup/execute-tests.sh