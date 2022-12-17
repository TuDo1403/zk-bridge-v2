pragma circom 2.0.2;

include "./eth.circom";

component main {public [blockHash, index]} = EthTransactionProof(6, 70, 210);
