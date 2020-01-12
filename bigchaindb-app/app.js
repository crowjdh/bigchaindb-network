const bigchain = require('bigchaindb-driver');
const bip39 = require('bip39');

function createConnection() {
    const API_PATH = 'http://bigchaindb-network_bigchaindb_1:9984/api/v1/';
    return new bigchain.Connection(API_PATH);
}

function createKeyPair(name) {
    const seed = bip39.mnemonicToSeed('seedPhrase' + name).slice(0, 32);

    return new bigchain.Ed25519Keypair(seed);
}

async function createPaint(conn, keyPair, painting) {
    const assets = { painting };
    const metadata = {
        datetime: new Date().toString(),
        location: 'Madrid',
        value: {
            value_eur: '25000000€',
            value_btc: '2200',
        }
    };
    const output = bigchain.Transaction.makeOutput(
        bigchain.Transaction.makeEd25519Condition(keyPair.publicKey));
    const issuers = keyPair.publicKey;

    const txCreatePaint = bigchain.Transaction.makeCreateTransaction(
        assets, metadata, [output], issuers,
    );
    const txSigned = bigchain.Transaction.signTransaction(txCreatePaint,
        keyPair.privateKey);

    console.log(`About to perform transaction with id: ${txSigned.id}`);
    const response = await conn.postTransactionCommit(txSigned);

    return response;
}

async function transferOwnership(conn, txPrevID, oldOwner, newOwner) {
    const txPrev = await conn.getTransaction(txPrevID);
    // The output index 0 is the one that is being spent
    const unspentOutput = {
        tx: txPrev,
        output_index: 0
    };
    const output = bigchain.Transaction.makeOutput(
        bigchain.Transaction.makeEd25519Condition(
            newOwner.publicKey
        ));
    const metadata = {
        datetime: new Date().toString(),
        value: {
            value_eur: '30000000€',
            value_btc: '2100',
        }
    };
    const createTranfer = bigchain.Transaction.makeTransferTransaction(
            [unspentOutput], [output], metadata);
    const signedTransfer = bigchain.Transaction.signTransaction(
        createTranfer, oldOwner.privateKey);
    const response = await conn.postTransactionCommit(signedTransfer);

    return response;
}

function main() {
    console.log("Creating connection...");
    const conn = createConnection();

    // if (true) {
    //     const id = "a6db186fb4600c8539cb7d5a9a35cc0ab6ec346e87ad31710d58e28bd240f8b2";
    //     conn.getTransaction(id).then(prettyJson).then(([prettyResponse, res]) => console.info(prettyResponse));
    //     // console.log('\n\n');
    //     // const assets = await conn.searchAssets('Rodríguez');
    //     return;
    // }

    console.log("Creating key pair...");
    const alice = createKeyPair('alice');
    console.log(`Key pair for Alice ready:\n\tPublic: ${alice.publicKey}\n\tPrivate: ${alice.privateKey}`);

    const painting = {
        name: 'Meninas',
        author: 'Diego Rodríguez de Silva y Velázquez',
        place: 'Madrid',
        year: '1656',
    };

    // conn.searchAssets('Rodríguez')
    // conn.getBlock(11)
    createPaint(conn, alice, painting)
        .then(prettyJson)
        .then(async ([prettyResponse, res]) => {
            console.log(`Transaction with id "${res.id}" completed with response:\n${prettyResponse}`);

            // return conn.getTransaction(res.id);
            // return conn.searchAssets('Rodríguez');

            // Wait for a while for create transaction to finish
            await new Promise(resolve => setTimeout(resolve, 3000));

            const bob = createKeyPair('bob');
            console.log(`Key pair for Bob ready:\n\tPublic: ${bob.publicKey}\n\tPrivate: ${bob.privateKey}`);

            return transferOwnership(conn, res.id, alice, bob);
        })
        .then(prettyJson)
        .then(([prettyResponse, res]) => {
            console.log(prettyResponse);
        })
        .catch(console.error);
}

function prettyJson(json) {
    return Promise.all([JSON.stringify(json, null, 2), json]);
}

main();
