FROM ubuntu@sha256:9a302811bba2ae9533ddae0b563af29c112f1262329e508f13c0c532d5ba7c19
WORKDIR /app
RUN apt-get update
RUN apt-get install -y wget
RUN wget https://github.com/Endava/cats/releases/download/cats-13.3.2/cats_linux_amd64_13.3.2.tar.gz
RUN tar -xvf cats_linux_amd64_13.3.2.tar.gz
ENTRYPOINT ["cat"]
