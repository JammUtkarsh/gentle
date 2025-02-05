# Same image as original Dockerfile lowquality/gentle
FROM python:3.9-slim

# Setting the working directory
WORKDIR /gentle

# Installing the dependencies
RUN apt-get update -y && apt install -y --no-install-recommends \ 
        gcc g++ gfortran curl \
        libc++-dev zlib1g-dev \
        automake autoconf libtool \
        git subversion \
        libatlas3-base \
        ffmpeg make patch bzip2 \
        python3 python3-dev python3-pip \
        sox python2.7 \
        wget unzip && \
        apt-get clean

# Copying files
COPY . .

# Boosting the build speed by using 10 cores; Remove this if you are not using a powerful machine
ARG MAKEFLAG=' -j1'
ENV MAKEFLAGS=$MAKEFLAG

# Running the installation scripts
RUN ./install.sh

# removing unecessary files to reduce the size of the image
RUN ./remove_excess.sh

EXPOSE 8765

VOLUME /gentle/webdata

CMD python3 /gentle/serve.py
