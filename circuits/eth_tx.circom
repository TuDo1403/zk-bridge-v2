pragma circom 2.0.2;

include "./eth.circom";

component main {public [blockHash, index]} = EthTransactionProof(6, 500, 1500);

// blockHash
// chainId
// tx index
// source sender
// dest receiver
// token address
// value
// nullifier [secret]
// nullifierHash
