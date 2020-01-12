#!/bin/bash

mkdir -p .temp

export TENDERMINT_1_NAME="Foo node"
export TENDERMINT_2_NAME="Bar node"

echo -n "Collecting validator info..."
export TENDERMINT_1_VALIDATOR_INFO=$(docker exec bigchaindb-network_tendermint_1 cat config/priv_validator_key.json)
export TENDERMINT_2_VALIDATOR_INFO=$(docker exec bigchaindb-network_tendermint_2 cat config/priv_validator_key.json)
echo "Done"

echo -n "Collecting genesis info..."
export GENESIS=$(docker exec bigchaindb-network_tendermint_1 cat config/genesis.json)
echo "Done"
echo ""

echo -n "Building genesis.json..."
node -e "
const tendermint1Info = JSON.parse(process.env.TENDERMINT_1_VALIDATOR_INFO);
const tendermint2Info = JSON.parse(process.env.TENDERMINT_2_VALIDATOR_INFO);

const genesis = JSON.parse(process.env.GENESIS);
const validatorTemplate = JSON.parse(JSON.stringify(genesis.validators[0]));
genesis.validators = [];

const tendermint1Validator = JSON.parse(JSON.stringify(validatorTemplate));
tendermint1Validator.address = tendermint1Info.address;
tendermint1Validator.pub_key = tendermint1Info.pub_key;
tendermint1Validator.name = process.env.TENDERMINT_1_NAME

genesis.validators.push(tendermint1Validator);

const tendermint2Validator = JSON.parse(JSON.stringify(validatorTemplate));
tendermint2Validator.address = tendermint2Info.address;
tendermint2Validator.pub_key = tendermint2Info.pub_key;
tendermint2Validator.name = process.env.TENDERMINT_2_NAME

genesis.validators.push(tendermint2Validator);

const genesisString = JSON.stringify(genesis, null, 2);
fs.writeFileSync('./.temp/genesis.json', genesisString);
"
echo "Done"

echo -n "Applying updated genesis.json..."
docker cp ./.temp/genesis.json bigchaindb-network_tendermint_1:/tendermint/config/genesis.json
docker cp ./.temp/genesis.json bigchaindb-network_tendermint_2:/tendermint/config/genesis.json
echo "Done"
echo ""

echo -n "Collecting tendermint node info..."
TENDERMINT_1_NODE_ID=$(docker exec bigchaindb-network_tendermint_1 tendermint show_node_id)
TENDERMINT_2_NODE_ID=$(docker exec bigchaindb-network_tendermint_2 tendermint show_node_id)

TENDERMINT_1_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' bigchaindb-network_tendermint_1)
TENDERMINT_2_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' bigchaindb-network_tendermint_2)
echo "Done"

do_sed()
{
    echo -n "Building config$1.toml..."
    docker exec bigchaindb-network_tendermint_$1 cat config/config.toml \
      | sed 's/moniker = .*/moniker = "'"$2"'"/g' \
      | sed 's/create_empty_blocks = .*/create_empty_blocks = false/g' \
      | sed 's/log_level = .*/log_level = "main:info,state:info,*:error"/g' \
      | sed 's/persistent_peers = .*/persistent_peers = "'"$TENDERMINT_1_NODE_ID"@"$TENDERMINT_1_IP":26656,"$TENDERMINT_2_NODE_ID"@"$TENDERMINT_2_IP":26656,'"/g' \
      | sed 's/send_rate = .*/send_rate = 102400000/g' \
      | sed 's/recv_rate = .*/recv_rate = 102400000/g' \
      | sed 's/recheck = .*/recheck = false/g' > ./.temp/config$1.toml
    echo "Done"

    echo -n "Applying config$1.toml..."
    docker cp ./.temp/config$1.toml bigchaindb-network_tendermint_$1:/tendermint/config/config.toml
    echo "Done"
}

do_sed 1 "$TENDERMINT_1_NAME"
do_sed 2 "$TENDERMINT_2_NAME"
echo ""
