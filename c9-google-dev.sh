#!/bin/bash

# Command
# gcloud compute instances create c9-google-dev --boot-disk-size 100GB \
#   --boot-disk-type pd-ssd --image ubuntu-15-04 --machine-type n1-standard-1 \
#   --metadata-from-file=startup-script=c9-google-dev.sh --zone us-central1-a \
#   --tags http-server,https-server,debug-http-server

echo "Google API Development with Cloud9 IDE"

apt-get update
apt-get -qq -y install build-essential git openjdk-8-jdk openjdk-8-source libarchive-dev pkg-config zip \
  g++ zlib1g-dev nodejs-legacy nodejs npm

git clone https://github.com/google/bazel bazel
git clone git://github.com/c9/core.git c9sdk

echo export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/ >> ~/.bashrc
source ~/.bashrc
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

cd bazel/
./compile.sh &

cd ..
cd c9sdk
scripts/install-sdk.sh

node server.js --port 8080 --collab --auth user:pass