FROM amazoncorretto@sha256:937a7f5c5f7ec41315f1c7238fd9ec0347684d6d99e086db81201ca21d1f5778

WORKDIR /app

RUN apk add --no-cache git wget
RUN wget https://github.com/WebFuzzing/EvoMaster/releases/download/v4.0.0/evomaster.jar

ENTRYPOINT [  \
    "java", \
    "-Xmx4G", \
    "-jar", "evomaster.jar", \
    "--runningInDocker", "true" \
]
