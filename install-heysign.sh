#!/bin/bash

usage() {
  echo "Usage)"
  echo "  export HEYSIGN_SERVER_IP=[your machine's public ip]"
  echo "  export HEYSIGN_BLOCKCHAIN_TYPE=[AERGO, NIPA, NONE]"
  echo "  ./install-heysign.sh <server-ip> <blockchain-type>"
  echo
  echo "    - server-ip: The public IP address of your machine"
  echo "                 This argument overrides HEYSIGN_SERVER_IP"
  echo
  echo "    - blockchain-type: The blockchain type for timestamping"
  echo "                       This argument overrides HEYSIGN_BLOCKCHAIN_TYPE"
  echo "                       ex) AERGO, NIPA, NONE"
}

SERVER_IP=${1:-$HEYSIGN_SERVER_IP}
BLOCKCHAIN_TYPE=${2:-$HEYSIGN_BLOCKCHAIN_TYPE}

if [ -z "$SERVER_IP" -o -z "$BLOCKCHAIN_TYPE" ]; then
  echo "Error) The required environment variables or arguments are not provided."
  echo "- provided HEYSIGN_SERVER_IP=$SERVER_IP"
  echo "- provided HEYSIGN_BLOCKCHAIN_TYPE=$BLOCKCHAIN_TYPE"
  echo
  echo "Please, see the following usage."
  usage
  exit 1
fi

in_array() {
  ARRAY=$2
  for ELEM in ${ARRAY[*]}; do
    if [ "$ELEM" == "$1" ]; then
      return 0
    fi
  done
  return 1
}

BC_TYPES=("AERGO" "NIPA" "NONE")

if ! in_array "$BLOCKCHAIN_TYPE" "${BC_TYPES[*]}"; then
  echo "Error) HEYSIGN_BLOCKCHAIN_TYPE must be one of (AERGO, NIPA, NONE)."
  echo "- provided HEYSIGN_BLOCKCHAIN_TYPE=$BLOCKCHAIN_TYPE"
  echo
  echo "Please, see the following usage."
  usage
  exit 1
fi

which_command_else_exit() {
  which $1 &> /dev/null
  if [ $? -ne 0 ]; then
    echo "Error) '$1' not found"
    exit 1
  fi
}

run_command_else_exit() {
  bash -c "$1" &> /dev/null
  if [ $? -ne 0 ]; then
    echo "Error) '$1' not working"
    exit 1
  fi
}

which_command_else_exit "git"
which_command_else_exit "docker"
run_command_else_exit "docker info"
which_command_else_exit "docker-compose"

DEST_DIR=$HOME/.heysign
SRC_DIR=$DEST_DIR/heysign-service/src/main/docker

if [ -d "$DEST_DIR" ]; then
  echo "Error) Directory already exists: $DEST_DIR"
  echo "You must remove it to continue to install HeySign."
  exit 1
fi

mkdir -p $DEST_DIR/config/database-init
mkdir -p $DEST_DIR/config/realm-config

cd $DEST_DIR
git clone https://bitbucket.org/opusm/heysign-service.git || exit 1
cd heysign-service
git checkout nipa || exit 1
cd ..

NIPA_IP=133.186.246.89

for FILE in $(ls $SRC_DIR/nipa); do
  sed "s/$NIPA_IP/$SERVER_IP/g" $SRC_DIR/nipa/$FILE > $DEST_DIR/$FILE
done

for FILE in $(ls $SRC_DIR/database-init); do
  sed "s/$NIPA_IP/$SERVER_IP/g" $SRC_DIR/database-init/$FILE > $DEST_DIR/config/database-init/$FILE
done

for FILE in $(ls $SRC_DIR/realm-config); do
  sed "s/$NIPA_IP/$SERVER_IP/g" $SRC_DIR/realm-config/$FILE > $DEST_DIR/config/realm-config/$FILE
done

sed -i "s/APPLICATION_TIMESTAMP_BLOCKCHAIN_TYPE=NIPA/APPLICATION_TIMESTAMP_BLOCKCHAIN_TYPE=$BLOCKCHAIN_TYPE/g" $DEST_DIR/app.yml

rm -rf $DEST_DIR/heysign-service

cd $DEST_DIR
chmod +x *.sh
./start_all_docker_containers.sh
