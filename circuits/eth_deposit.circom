pragma circom 2.0.2;

include "../node_modules/circomlib/circuits/poseidon.circom";

include "./eth.circom";
include "./util.circom";

// blockHash
// chainId
// tx index
// source sender
// dest receiver
// token address
// value
// nullifier [secret]
// nullifierHash

template DepositProof(maxDepth, maxIndex, maxTxRlpHexLen) {
    var maxLeafRlpHexLen = 4 + (6 + 2) + 4 + maxTxRlpHexLen;
    var maxBranchRlpHexLen = 1064;

    // public input
    signal input token;
    signal input value;
    signal input receiver;
    signal input blockHash[2];
    signal input nullifierHash;

    // deposit secret
    signal input txIdx;
    signal input nullifier;
    signal input depositId;

    // block secret

    // block input
    signal input blockRlpHexs[1112];

    // MPT inclusion inputs
    signal input txRlpHexs[maxTxRlpHexLen];
    signal input keyFragmentStarts[maxDepth];

    signal input leafRlpHexs[maxLeafRlpHexLen];
    signal input leafPathPrefixHexLen;
    
    signal input nodeRlpHexs[maxDepth - 1][maxBranchRlpHexLen];
    signal input nodePathPrefixHexLen[maxDepth - 1];

    // index 0 = root; value 0 = branch, 1 = extension
    signal input nodeTypes[maxDepth - 1];
    signal input depth;

    signal output out;
    signal output isCall;
    signal output methodId;

    // logic

    /// check nullifier
    component nullifierHasher = Poseidon(2);
    nullifierHasher.inputs[0] <== nullifier;
    nullifierHasher.inputs[1] <== 0;

    nullifierHasher.out === nullifierHash;

    /// check tx inclusion logic

    component tx_pf = EthTransactionProofCore(maxDepth, maxIndex, maxTxRlpHexLen);
    tx_pf.blockHash[0] <== blockHash[0];
    tx_pf.blockHash[1] <== blockHash[1];
    tx_pf.index <== txIdx;
    
    for (var idx = 0; idx < 1112; idx++) {
        tx_pf.blockRlpHexs[idx] <== blockRlpHexs[idx];
    }
    for (var idx = 0; idx < maxTxRlpHexLen; idx++) {
	    tx_pf.txRlpHexs[idx] <== txRlpHexs[idx];
    }
    for (var idx = 0; idx < maxDepth; idx++) {
	    tx_pf.keyFragmentStarts[idx] <== keyFragmentStarts[idx];
    }
    for (var idx = 0; idx < maxLeafRlpHexLen; idx++) {
	    tx_pf.leafRlpHexs[idx] <== leafRlpHexs[idx];
    }

    tx_pf.leafPathPrefixHexLen <== leafPathPrefixHexLen;
    
    for (var idx = 0; idx < maxDepth - 1; idx++) {
        for (var j = 0; j < maxBranchRlpHexLen; j++) {
            tx_pf.nodeRlpHexs[idx][j] <== nodeRlpHexs[idx][j];
        }
    }
    for (var idx = 0; idx < maxDepth - 1; idx++) {
        tx_pf.nodePathPrefixHexLen[idx] <== nodePathPrefixHexLen[idx];
        tx_pf.nodeTypes[idx] <== nodeTypes[idx];
    }

    tx_pf.depth <== depth;

    out <== tx_pf.out;

    component iz = IsZero();
    iz.in <== tx_pf.dataHexLen;
    isCall <== 1 - iz.out;

    var temp = 0;
    for (var i = 0; i < 8; i++) {
	    temp = temp + tx_pf.dataHexs[i] * (16 ** (7 - i));
    }

    methodId <== isCall * temp;
    log(14321990);
    log(methodId);
    methodId === depositId;

    temp = 0;
    for (var i = 8; i < 72; i++) {
        temp = temp + tx_pf.dataHexs[i] * (16 ** (71 - i));
    }
    log(14321991);
    log(temp);
    token === temp;

    temp = 0;
    for (var i = 72; i < 136; i++) {
        temp = temp + tx_pf.dataHexs[i] * (16 ** (135 - i));
    }
    log(14321992);
    log(temp);
    value === temp;

    temp = 0;
    for (var i = 136; i < 200; i++) {
        temp = temp + tx_pf.dataHexs[i] * (16 ** (199 - i));
    }
    log(14321993);
    log(temp);

    component commitmentHasher = Poseidon(2);
    commitmentHasher.inputs[0] <== nullifier;
    commitmentHasher.inputs[1] <== 1;

    commitmentHasher.out === temp;
}

// signal input value;
// signal input sender;
// signal input receiver;
// signal input tokenAddress;
// signal input blockHash[2];
// signal input nullifierHash;

component main {
    public [
        token,
        value,
        receiver, 
        blockHash, 
        nullifierHash
    ]
} = DepositProof(6, 500, 15000);