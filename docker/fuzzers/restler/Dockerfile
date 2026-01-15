FROM mcr.microsoft.com/dotnet/sdk@sha256:0f31419f1f4f6687dd29f8c12c135ef401ad75a695995fdef1d55ada6665c2c0 AS builder
WORKDIR /app

RUN apk add --no-cache python3 py3-pip git
RUN git clone https://github.com/microsoft/restler-fuzzer.git
WORKDIR /app/restler-fuzzer
RUN git checkout eaacd92733771d35e90acfb2040fe37d4e5d09b1

RUN python3 build-restler.py --dest_dir /build

RUN python3 -m compileall -b /build/engine

FROM mcr.microsoft.com/dotnet/aspnet@sha256:6faef52a037435524fcda33d94a23cada50eed3775849efa863bf0d45327403c AS target

RUN apk add --no-cache python3 py3-pip

# Create a virtual environment
RUN python3 -m venv /venv

# Activate the virtual environment and install packages
RUN /venv/bin/pip install applicationinsights requests

# Ensure the virtual environment is activated by default
ENV PATH="/venv/bin:$PATH"

RUN mkdir outputs
RUN cd outputs


COPY --from=builder /build /RESTler

