#!/bin/bash

# Command
# gcloud compute instances create c9-google-dev --boot-disk-size 100GB \
#   --boot-disk-type pd-ssd --image ubuntu-15-04 --machine-type n1-standard-1 \
#   --metadata-from-file=startup-script=c9-google-dev.sh --zone us-central1-a \
#   --tags http-server,https-server,debug-http-server

TARGET_USER=root
TARGET_USER_HOME=/home/${TARGET_USER}
APP_ROOT=${TARGET_USER_HOME}/apps
WORKSPACE_ROOT=${TARGET_USER_HOME}/workspace
JVM_ROOT=/usr/lib/jvm/java-8-openjdk-amd64

function RunAsUser() {
  local CWD=$(pwd)
  su - ${TARGET_USER} -c "cd ${CWD}; $1"
}

function Initialize() {
  echo "Google API Development with Cloud9 IDE"
  echo "======================================"
  systemctl disable accounts-daemon.service
  systemctl stop accounts-daemon.service
  useradd -G adm,sudo,dip,video,plugdev -d ${TARGET_USER_HOME} -m ${TARGET_USER} 
  RunAsUser "mkdir -p ${APP_ROOT}; mkdir -p ${WORKSPACE_ROOT}"
  RunAsUser "touch ${WORKSPACE_ROOT}/WORKSPACE"
}

function InstallPackages() {
  apt-get update
  apt-get -qq -y install build-essential git openjdk-8-jdk openjdk-8-source \
    libarchive-dev pkg-config zip g++ zlib1g-dev nodejs-legacy nodejs npm \
    golang python-all-dev python-virtualenv libtool autoconf
}

function InstallBazel() {
  cd ${APP_ROOT}
  RunAsUser "git clone --recursive https://github.com/google/bazel bazel"
  cd bazel/
  RunAsUser "export JAVA_HOME=${JVM_ROOT}; ./compile.sh"
  # export PATH="$PATH:$HOME/bazel/output"
  cd base_workspace
  RunAsUser "${APP_ROOT}/bazel/ouput/bazel build //scripts:bazel-complete.bash"
  echo export PATH="$PATH:${APP_ROOT}/bazel/output" >> ${TARGET_USER_HOME}/.bashrc
  # bazel-bin/scripts/bazel-complete.bash
  cd ${WORKSPACE_ROOT}
  RunAsUser "${APP_ROOT}/bazel/output/bazel fetch //..."
}

function InstallGrpc() {
  cd ${APP_ROOT}
  RunAsUser "git clone --recursive https://github.com/google/protobuf.git protobuf"
  cd protobuf
  git checkout v3.0.0-alpha-2
  RunAsUser "./autogen.sh"
  RunAsUser "./configure"
  RunAsUser "make"
  RunAsUser "make check"
  make install
  
  cd ${APP_ROOT}
  RunAsUser "git clone --recursive https://github.com/grpc/grpc.git grpc"
  cd grpc
  RunAsUser "make"
  make install
  
  cd ${APP_ROOT}
  RunAsUser "git clone --recursive https://github.com/grpc/grpc-java.git grpc-java"
  cd grpc-java
  RunAsUser "./gradlew build"
}
  
function InstallCloud9() {
  cd ${APP_ROOT}
  RunAsUser "git clone --recursive git://github.com/c9/core.git c9sdk"
  cd c9sdk/
  RunAsUser "scripts/install-sdk.sh"
  npm install http-error ejs connect netutil optimist socket.io
  
  
  cat <<EOF >> /lib/systemd/system/cloud9.service

[Unit]
Description=Cloud 9 IDE
After=syslog.target

[Service]
User=${TARGET_USER}
Type=forking
PIDFile=/var/run/cloud9.pid
WorkingDirectory=${APP_ROOT}/c9sdk
ExecStart=/usr/bin/node ${APP_ROOT}/c9sdk/server.js -w ${WORKSPACE_ROOT} \
  --port 8080 --listen 0.0.0.0 --auth user:pass
Restart=always

[Install]
WantedBy=multi-user.target

EOF

  systemctl enable cloud9.service
  systemctl start cloud9.service
}

Initialize
InstallPackages
InstallBazel
InstallGrpc
InstallCloud9
