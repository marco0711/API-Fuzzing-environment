FROM python:3.9


WORKDIR /app
RUN apt-get update
RUN apt-get install -y git
RUN pip install pyyaml requests
RUN git clone https://github.com/marco0711/Marker-REST_API_Fuzzer.git marker
WORKDIR /app/marker
