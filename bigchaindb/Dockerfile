FROM ubuntu:18.04

RUN apt-get update && apt install -y python3-pip libssl-dev
RUN pip3 install -U pip
RUN pip install bigchaindb==2.0.0

RUN apt-get install -y gettext-base

COPY .bigchaindb-template /root/.bigchaindb-template
