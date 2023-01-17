include "./bsc.circom";
include "./util.circom";

include "../node_modules/circomlib/circuits/poseidon.circom";

template BscDepositProof(maxDepth, maxIndex, maxTxRlpHexLen) {
    var maxLeafRlpHexLen = 4 + (6 + 2) + 4 + maxTxRlpHexLen;
    var maxBranchRlpHexLen = 1064;

    // public input
    signal input token;
    signal input value;
    signal input receiver;
    signal input bridgeSource;
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
    
    for (var idx = 0; idx < 1112; idx++) 
        tx_pf.blockRlpHexs[idx] <== blockRlpHexs[idx];
    
    for (var idx = 0; idx < maxTxRlpHexLen; idx++) 
	    tx_pf.txRlpHexs[idx] <== txRlpHexs[idx];
    
    for (var idx = 0; idx < maxDepth; idx++) 
	    tx_pf.keyFragmentStarts[idx] <== keyFragmentStarts[idx];
    
    for (var idx = 0; idx < maxLeafRlpHexLen; idx++) 
	    tx_pf.leafRlpHexs[idx] <== leafRlpHexs[idx];

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

    // check is contract interaction tx
    component iz = IsZero();
    iz.in <== tx_pf.dataHexLen;
    isCall <== 1 - iz.out;

    // check `to` field match bridge contract address
    var temp = 0;
    for (var i = 0; i < 40; i++) {
        temp = temp + tx_pf.toHexs[i] * (16 ** (39 - i));
    }
    bridgeSource === temp;

    // check function call match deposit fnSig
    temp = 0;
    for (var i = 0; i < 8; i++) {
	    temp = temp + tx_pf.dataHexs[i] * (16 ** (7 - i));
    }

    methodId <== isCall * temp;
    log(14321990);
    log(methodId);
    methodId === depositId;

    // check token address match public input
    temp = 0;
    for (var i = 8; i < 72; i++) {
        temp = temp + tx_pf.dataHexs[i] * (16 ** (71 - i));
    }
    log(14321991);
    log(temp);
    token === temp;

    // check token value match public input
    temp = 0;
    for (var i = 72; i < 136; i++) {
        temp = temp + tx_pf.dataHexs[i] * (16 ** (135 - i));
    }
    log(14321992);
    log(temp);
    value === temp;

    // check preimage of commitment
    temp = 0;
    for (var i = 136; i < 200; i++) 
        temp = temp + tx_pf.dataHexs[i] * (16 ** (199 - i));
    
    log(14321993);
    log(temp);

    component commitmentHasher = Poseidon(2);
    commitmentHasher.inputs[0] <== nullifier;
    commitmentHasher.inputs[1] <== 1;

    commitmentHasher.out === temp;
}

