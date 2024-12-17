# This dockerfile sets up a energyLedge backend database running inside a Docker container

FROM postgres:17-bookworm

LABEL description="energyLedger"
LABEL maintainer="info@openriskmanagement.com"
LABEL version="0.2"
LABEL author="Open Risk <www.openriskmanagement.com>"

RUN apt update && apt upgrade -y
RUN apt install postgresql postgresql-client -y
RUN apt install postgresql-plpython3-17 -y

COPY ./init.sql /docker-entrypoint-initdb.d/init.sql
RUN chown postgres:postgres /docker-entrypoint-initdb.d/init.sql
EXPOSE 5432
