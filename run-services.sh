#!/bin/bash

# Run services
docker-compose up -d --scale bigchaindb=2 --scale mongodb=2 --scale tendermint=2

# Init tendermint
docker exec bigchaindb-network_tendermint_1 tendermint init
docker exec bigchaindb-network_tendermint_2 tendermint init

./config.sh

# Run BigchainDB
echo -n "Running BigchainDB..."
docker exec -d bigchaindb-network_bigchaindb_1 bigchaindb start
docker exec -d bigchaindb-network_bigchaindb_2 bigchaindb start
echo "Done"
echo ""

echo "Sleep for 10 seconds for bigchaindb to start properly"
sleep 10

# Run Tendermint
echo -n "Running Tendermint..."
docker exec -d bigchaindb-network_tendermint_1 bash -c "tendermint node --proxy_app=tcp://bigchaindb-network_bigchaindb_1:26658 &> tendermint.log"
docker exec -d bigchaindb-network_tendermint_2 bash -c "tendermint node --proxy_app=tcp://bigchaindb-network_bigchaindb_2:26658 &> tendermint.log"
echo "Done"
