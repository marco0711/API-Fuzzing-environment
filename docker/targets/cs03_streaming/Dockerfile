FROM alpine:3.21
ARG version=8.452.09.1
ARG TARGET_BRANCH
ARG FORK_OWNER
LABEL port="8080"

# Please note that the THIRD-PARTY-LICENSE could be out of date if the base image has been updated recently.
# The Corretto team will update this file but you may see a few days' delay.
RUN wget -O /THIRD-PARTY-LICENSES-20200824.tar.gz https://corretto.aws/downloads/resources/licenses/alpine/THIRD-PARTY-LICENSES-20200824.tar.gz && \
    echo "82f3e50e71b2aee21321b2b33de372feed5befad6ef2196ddec92311bc09becb  /THIRD-PARTY-LICENSES-20200824.tar.gz" | sha256sum -c - && \
    tar x -ovzf THIRD-PARTY-LICENSES-20200824.tar.gz && \
    rm -rf THIRD-PARTY-LICENSES-20200824.tar.gz && \
    wget -O /etc/apk/keys/amazoncorretto.rsa.pub https://apk.corretto.aws/amazoncorretto.rsa.pub && \
    SHA_SUM="6cfdf08be09f32ca298e2d5bd4a359ee2b275765c09b56d514624bf831eafb91" && \
    echo "${SHA_SUM}  /etc/apk/keys/amazoncorretto.rsa.pub" | sha256sum -c - && \
    echo "https://apk.corretto.aws" >> /etc/apk/repositories && \
    apk add --no-cache amazon-corretto-8=$version-r0 && \
    rm -rf /usr/lib/jvm/java-8-amazon-corretto/lib/src.zip


RUN apk add git maven zip wget

ENV LANG=C.UTF-8
ENV JAVA_HOME=/usr/lib/jvm/default-jvm
ENV PATH=$PATH:/usr/lib/jvm/default-jvm/bin
ARG PROJECT_ROOT=/api_case_studies/cs03_streaming
ENV CLASS_FILES=$PROJECT_ROOT/build/classes
ENV JACOCOCLI_PATH=$PROJECT_ROOT/lib/jacococli.jar
ENV JACOCOAGENT_PATH=$PROJECT_ROOT/lib/jacocoagent.jar
ENV HTML_PATH=/output
ENV NAME=jacoco_report
ENV REPORT_NAME=jacoco_report
ENV JACOCO_PORT=10001

RUN echo -e "#!/bin/sh\n" \
    "java -jar $JACOCOCLI_PATH dump " \
    "--address localhost " \
    "--port $JACOCO_PORT " \
    "--destfile ./jacoco.exec && " \
    "java -jar $JACOCOCLI_PATH report ./jacoco.exec " \
    "--classfiles $CLASS_FILES" \
    "--sourcefiles $PROJECT_ROOT/src "\
    "--html $HTML_PATH  " \
    "--name $NAME" > output.sh

RUN chmod +x output.sh

RUN git clone https://github.com/$FORK_OWNER/api_case_studies.git
WORKDIR $PROJECT_ROOT
RUN git checkout origin/$TARGET_BRANCH
RUN wget -O jacoco.zip https://github.com/jacoco/jacoco/releases/download/v0.8.13/jacoco-0.8.13.zip
RUN unzip jacoco.zip

RUN chmod +x ./gradlew
RUN ./gradlew clean
RUN ./gradlew build

ENTRYPOINT ["java","-javaagent:lib/jacocoagent.jar=output=tcpserver,address=*,port=10001","-jar","build/libs/live-streaming.jar"]
