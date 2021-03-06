#!/bin/bash

set -eu
set -o pipefail

cd "$(dirname "$0")"

rm -rf data

# Setup inspired by
# https://docs.mongodb.com/manual/tutorial/deploy-replica-set-for-testing/

mkdir -p data/s0 data/s1

./mongod --port 21000 --dbpath "$PWD/data/s0" --replSet rs0 --smallfiles --oplogSize 128 >data/s0.log 2>&1 &
PID0=$!
./mongod --port 21001 --dbpath "$PWD/data/s1" --replSet rs0 --smallfiles --oplogSize 128 >data/s1.log 2>&1 &
PID1=$!

echo "Running 2 mongod servers (PIDs $PID0 and $PID1)"

# shellcheck disable=SC2064
trap "echo 'Killing mongod'; kill $PID0 $PID1" EXIT

echo "Trying to initiate replicaset"

while true; do
  if ./mongo --port 21000 --eval 'printjson(rs.initiate({_id: "rs0", members: [{_id: 0, host: "127.0.0.1:21000"}, {_id: 1, host: "127.0.0.1:21001"}]}))'; then
    echo "Initiated"
    break
  fi
  sleep 1
done


echo "Waiting for one to be PRIMARY"

while true; do
  if ./mongo --port 21000 --eval 'printjson(rs.status())' | grep PRIMARY; then
    echo "PRIMARY found"
    break
  fi
  sleep 1
done

wait $PID0
wait $PID1
