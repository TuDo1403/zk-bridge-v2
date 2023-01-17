pragma circom 2.0.2;

include "./utils/mpt.circom";
include "./utils/rlp.circom";
include "./utils/keccak.circom";

include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/multiplexer.circom";

/*
    This is a template for a circuit in the Circom (Circuit Composer) language, which is used to build zero-knowledge proofs. The circuit is called "BscBlockHashHex" and its purpose is to compute the hash of a block header in the Binance Smart Chain (BSC) blockchain.

    The input to the circuit is an array of 1112 hexadecimal values, representing the RLP encoding of the block header. The circuit has several outputs:

    "out" is a boolean value indicating whether the input RLP encoding is valid.
    "number" is an array of 6 values representing the block number.
    "numberHexLen" is the length of the block number in hexadecimal.
    "stateRoot", "receiptsRoot", and "transactionsRoot" are arrays of 64 values each, representing the state root, receipts root, and transactions root of the block, respectively.
    "blockHashHexs" is an array of 64 values representing the block hash in hexadecimal.
    
    The circuit first uses the "RlpArrayCheck" component to check the validity of the input RLP encoding and extract the values of the various fields in the block header. It then uses the "ReorderPad101Hex" component to pad the RLP encoding to a fixed length of 1360 hexadecimal values. The "LessEqThan" component is used to determine whether the padded RLP encoding is less than or equal to 1088 hexadecimal values in length. If it is, then 4 rounds of the Keccak-256 hash function are used to compute the block hash; otherwise, 5 rounds are used. The block hash is then returned as an output.
*/

template BscPreSealedBlockHashHex() {
    // public
    signal input blockRlpHexs[1112];

    signal output out;
    signal output number[6];
    signal output numberHexLen;
    signal output stateRoot[64];
    signal output receiptsRoot[64];	
    signal output blockHashHexs[64];
    signal output transactionsRoot[64];		

    component rlp = RlpArrayCheck(
        1112, 
        16, 
        4,
        // chainId, ParentHash, UncleHash, Coinbase, Root, TxHash, ReceiptHash, Bloom, Difficulty, Number, GasLimit, GasUsed, Time, Extra, MixDigest, Nonce
        [2, 64, 64, 40, 64, 64, 64, 512,  0, 0, 0, 0, 0,  0, 64, 16],
		[8, 64, 64, 40, 64, 64, 64, 512, 14, 8, 8, 8, 8, 64, 64, 18]
    );

    for (var idx = 0; idx < 1112; idx++) 
    	rlp.in[idx] <== blockRlpHexs[idx];

    var blockRlpHexLen = rlp.totalRlpHexLen;
    component pad = ReorderPad101Hex(1016, 1112, 1360, 13);
    pad.inLen <== blockRlpHexLen;

    for (var idx = 0; idx < 1112; idx++) 
        pad.in[idx] <== blockRlpHexs[idx];
    
    // if leq.out == 1, use 4 rounds, else use 5 rounds
    component leq = LessEqThan(13);
    leq.in[0] <== blockRlpHexLen + 1;
    // 4 * blockSize = 1088
    leq.in[1] <== 1088;
    
    var blockSizeHex = 136 * 2;
    component keccak = Keccak256Hex(5);
    for (var idx = 0; idx < 5 * blockSizeHex; idx++) 
        keccak.inPaddedHex[idx] <== pad.out[idx];
    
    keccak.rounds <== 5 - leq.out;

    out <== rlp.out;

    for (var idx = 0; idx < 32; idx++) {
        blockHashHexs[2 * idx] <== keccak.out[2 * idx + 1];
	    blockHashHexs[2 * idx + 1] <== keccak.out[2 * idx];
    }

    for (var idx = 0; idx < 64; idx++) {
    	stateRoot[idx] <== rlp.fields[4][idx];
    	receiptsRoot[idx] <== rlp.fields[6][idx];
    	transactionsRoot[idx] <== rlp.fields[5][idx];
    }

    numberHexLen <== rlp.fieldHexLen[9];
    for (var idx = 0; idx < 6; idx++) 
        number[idx] <== rlp.fields[9][idx];
}

template BscTransactionProofCore(maxDepth, maxIndex, maxTxRlpHexLen) {
    var maxLeafRlpHexLen = 4 + (6 + 2) + 4 + maxTxRlpHexLen;
    var maxBranchRlpHexLen = 1064;

    signal input index;
    signal input blockHash[2];    // 128 bit coordinates

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

    signal output txType;  // 0 if type 0, 1 if type 2 (post EIP-1559)

    signal output nonceHexLen;
    signal output gasPriceHexLen;
    signal output gasLimitHexLen;
    signal output valueHexLen;
    signal output dataHexLen;

    signal output nonceHexs[64];
    signal output gasPriceHexs[64];
    signal output gasLimitHexs[64];
    signal output toHexs[40];    
    signal output valueHexs[64];
    signal output dataHexs[maxTxRlpHexLen - 170];
    signal output vHexs[2];
    signal output rHexs[64];
    signal output sHexs[64];

    // fields only in type 2
    signal output chainIdHexLen;
    signal output maxPriorityFeeHexLen;

    signal output chainIdHexs[2];
    signal output maxPriorityFeeHexs[64];
    
    // decode compressed inputs
    signal blockHashHexs[64];
    component blockHashN2b[2];
    for (var idx = 0; idx < 2; idx++) {
    	blockHashN2b[idx] = Num2Bits(128);
	    blockHashN2b[idx].in <== blockHash[idx];

        for (var j = 0; j < 32; j++) {
            blockHashHexs[32 * idx + j] <== 8 * blockHashN2b[idx].out[4 * (31 - j) + 3] + 4 * blockHashN2b[idx].out[4 * (31 - j) + 2] + 2 * blockHashN2b[idx].out[4 * (31 - j) + 1] + blockHashN2b[idx].out[4 * (31 - j)];
        }
    }

    // validate index
    component index_lt = LessThan(10);
    index_lt.in[0] <== index;
    index_lt.in[1] <== maxIndex;

    // match block hash 
    component block_hash = BscPreSealedBlockHashHex();
    for (var idx = 0; idx < 1112; idx++) 
	    block_hash.blockRlpHexs[idx] <== blockRlpHexs[idx];
    

    component block_hash_check = ArrayEq(64);
    for (var idx = 0; idx < 64; idx++) {
        block_hash_check.b[idx] <== blockHashHexs[idx];
        block_hash_check.a[idx] <== block_hash.blockHashHexs[idx];
    }
    block_hash_check.inLen <== 64;

    // determine tx type
    component tx_type_1 = IsEqual();
    tx_type_1.in[0] <== txRlpHexs[0];
    tx_type_1.in[1] <== 0;	

    component tx_type_2 = IsEqual();
    tx_type_2.in[0] <== txRlpHexs[1];
    tx_type_2.in[1] <== 2;

    txType <== tx_type_1.out * tx_type_2.out;

    // check tx info is properly formatted
    var maxArrayPrefix1HexLen = 2 * (log_ceil(maxTxRlpHexLen) \ 8 + 1);
    component rlp0 = RlpArrayCheck(
        maxTxRlpHexLen, 
        9, 
        maxArrayPrefix1HexLen,
        [0, 0, 0, 40, 0, 0, 0, 64, 64],
		[64, 64, 64, 40, 64, maxTxRlpHexLen - 170, 2, 64, 64]
    );

    for (var idx = 0; idx < maxTxRlpHexLen; idx++) 
        rlp0.in[idx] <== (1 - txType) * txRlpHexs[idx];

    // assume access list is empty
    component rlp2 = RlpArrayCheck(
        maxTxRlpHexLen - 2, 
        12, 
        maxArrayPrefix1HexLen,
        [0, 0, 0, 0, 0, 40, 0, 0, 0, 0, 64, 64],
		[2, 64, 64, 64, 64, 40, 64, maxTxRlpHexLen - 172, 0, 2, 64, 64]
    );

    for (var idx = 0; idx < maxTxRlpHexLen - 2; idx++) 
        rlp2.in[idx] <== txType * txRlpHexs[idx + 2];
    
    signal tx_rlp_check;
    tx_rlp_check <== rlp0.out + txType * (rlp2.out - rlp0.out);

    // read out tx fields
    nonceHexLen <== rlp0.fieldHexLen[0] + txType * (rlp2.fieldHexLen[1] - rlp0.fieldHexLen[0]);
    gasPriceHexLen <== rlp0.fieldHexLen[1] + txType * (rlp2.fieldHexLen[3] - rlp0.fieldHexLen[1]);
    gasLimitHexLen <== rlp0.fieldHexLen[2] + txType * (rlp2.fieldHexLen[4] - rlp0.fieldHexLen[2]);
    valueHexLen <== rlp0.fieldHexLen[4] + txType * (rlp2.fieldHexLen[6] - rlp0.fieldHexLen[4]);
    dataHexLen <== rlp0.fieldHexLen[5] + txType * (rlp2.fieldHexLen[7] - rlp0.fieldHexLen[5]);

    for (var idx = 0; idx < 64; idx++) {
    	nonceHexs[idx] <== rlp0.fields[0][idx] + txType * (rlp2.fields[1][idx] - rlp0.fields[0][idx]);
        valueHexs[idx] <== rlp0.fields[4][idx] +  txType * (rlp2.fields[6][idx] - rlp0.fields[4][idx]);
        gasPriceHexs[idx] <== rlp0.fields[1][idx] + txType * (rlp2.fields[3][idx] - rlp0.fields[1][idx]);
        gasLimitHexs[idx] <== rlp0.fields[2][idx] + txType * (rlp2.fields[4][idx] - rlp0.fields[2][idx]);
        rHexs[idx] <== rlp0.fields[7][idx] + txType * (rlp2.fields[10][idx] - rlp0.fields[7][idx]);
        sHexs[idx] <== rlp0.fields[8][idx] + txType * (rlp2.fields[11][idx] - rlp0.fields[8][idx]);
    }
    
    // for (var idx = 0; idx < 64; idx++) 
    //     gasPriceHexs[idx] <== rlp0.fields[1][idx] + txType * (rlp2.fields[3][idx] - rlp0.fields[1][idx]);
    
    // for (var idx = 0; idx < 64; idx++) 
    //     gasLimitHexs[idx] <== rlp0.fields[2][idx] + txType * (rlp2.fields[4][idx] - rlp0.fields[2][idx]);
    
    for (var idx = 0; idx < 40; idx++) 
        toHexs[idx] <== rlp0.fields[3][idx] + txType * (rlp2.fields[5][idx] - rlp0.fields[3][idx]);
    
    // for (var idx = 0; idx < 64; idx++) 
    //     valueHexs[idx] <== rlp0.fields[4][idx] +  txType * (rlp2.fields[6][idx] - rlp0.fields[4][idx]);
    
    for (var idx = 0; idx < maxTxRlpHexLen - 172; idx++) 
        dataHexs[idx] <== rlp0.fields[5][idx] + txType * (rlp2.fields[7][idx] - rlp0.fields[5][idx]);
    
    for (var idx = maxTxRlpHexLen - 172; idx < maxTxRlpHexLen - 170; idx++) 
        dataHexs[idx] <== rlp0.fields[5][idx] * (1 - txType);
    
    for (var idx = 0; idx < 2; idx++)
        vHexs[idx] <== rlp0.fields[6][idx] + txType * (rlp2.fields[9][idx] - rlp0.fields[6][idx]);
    
    // for (var idx = 0; idx < 64; idx++) 
    //     rHexs[idx] <== rlp0.fields[7][idx] + txType * (rlp2.fields[10][idx] - rlp0.fields[7][idx]);
    
    // for (var idx = 0; idx < 64; idx++) 
    //     sHexs[idx] <== rlp0.fields[8][idx] + txType * (rlp2.fields[11][idx] - rlp0.fields[8][idx]);

    chainIdHexLen <== rlp2.fieldHexLen[0];
    maxPriorityFeeHexLen <== rlp2.fieldHexLen[2];

    for (var idx = 0; idx < 2; idx++) 
	    chainIdHexs[idx] <== rlp2.fields[0][idx];
    
    for (var idx = 0; idx < 64; idx++) 
        maxPriorityFeeHexs[idx] <== rlp2.fields[2][idx];

    signal rlpIndexHexs[6];
    signal rlpIndexHexLen;

    // if index == 0, then 80
    // if index in [0, 127], then index literal
    // if index in [128, 255], then 81[index]
    // if index > 255, then 82[index]
    component index_zero = IsZero();
    index_zero.in <== index;

    component index_rlp_lt1 = LessThan(16);
    index_rlp_lt1.in[0] <== index;
    index_rlp_lt1.in[1] <== 128;

    component index_rlp_lt2 = LessThan(16);
    index_rlp_lt2.in[0] <== index;
    index_rlp_lt2.in[1] <== 256;
    
    component index_n2b = Num2Bits(16);
    index_n2b.in <== index;

    rlpIndexHexLen <== 6 - 4 * index_rlp_lt1.out - 2 * index_rlp_lt2.out + 2 * index_rlp_lt1.out * index_rlp_lt2.out;
    signal rlpIndex_temp[4];
    rlpIndex_temp[0] <== index_rlp_lt1.out * (index_n2b.out[4] + 2 * index_n2b.out[5] + 4 * index_n2b.out[6] + 8 * index_n2b.out[7] - 8) + 8;
    rlpIndex_temp[1] <== index_rlp_lt1.out * (index_n2b.out[0] + 2 * index_n2b.out[1] + 4 * index_n2b.out[2] + 8 * index_n2b.out[3] - 2) + 2 - index_rlp_lt2.out;
    rlpIndex_temp[2] <== (1 - index_rlp_lt1.out) * (index_n2b.out[4] + 2 * index_n2b.out[5] + 4 * index_n2b.out[6] + 8 * index_n2b.out[7]);
    rlpIndex_temp[3] <== (1 - index_rlp_lt1.out) * (index_n2b.out[0] + 2 * index_n2b.out[1] + 4 * index_n2b.out[2] + 8 * index_n2b.out[3]);
    
    rlpIndexHexs[0] <== index_zero.out * (8 - rlpIndex_temp[0]) + rlpIndex_temp[0];
    rlpIndexHexs[1] <== (1 - index_zero.out) * rlpIndex_temp[1];
    
    rlpIndexHexs[2] <== (index_n2b.out[12] + 2 * index_n2b.out[13] + 4 * index_n2b.out[14] + 8 * index_n2b.out[15]) + index_rlp_lt2.out * (rlpIndex_temp[2] - (index_n2b.out[12] + 2 * index_n2b.out[13] + 4 * index_n2b.out[14] + 8 * index_n2b.out[15]));
    rlpIndexHexs[3] <== (index_n2b.out[8] + 2 * index_n2b.out[9] + 4 * index_n2b.out[10] + 8 * index_n2b.out[11]) + index_rlp_lt2.out * (rlpIndex_temp[3] - (index_n2b.out[8] + 2 * index_n2b.out[9] + 4 * index_n2b.out[10] + 8 * index_n2b.out[11]));
    
    rlpIndexHexs[4] <== (1 - index_rlp_lt2.out) * (index_n2b.out[4] + 2 * index_n2b.out[5] + 4 * index_n2b.out[6] + 8 * index_n2b.out[7]);
    rlpIndexHexs[5] <== (1 - index_rlp_lt2.out) * (index_n2b.out[0] + 2 * index_n2b.out[1] + 4 * index_n2b.out[2] + 8 * index_n2b.out[3]);

    // validate MPT inclusion
    component mpt = MPTInclusionNoBranchTermination(maxDepth, 6, maxTxRlpHexLen);
    for (var idx = 0; idx < 6; idx++) 
	    mpt.keyHexs[idx] <== rlpIndexHexs[idx];
    
    mpt.keyHexLen <== rlpIndexHexLen;
    for (var idx = 0; idx < maxTxRlpHexLen; idx++) 
	    mpt.valueHexs[idx] <== txRlpHexs[idx];
    
    for (var idx = 0; idx < 64; idx++) 
	    mpt.rootHashHexs[idx] <== block_hash.transactionsRoot[idx];

    for (var idx = 0; idx < maxDepth; idx++) 
    	mpt.keyFragmentStarts[idx] <== keyFragmentStarts[idx];

    mpt.leafPathPrefixHexLen <== leafPathPrefixHexLen;
    for (var idx = 0; idx < maxLeafRlpHexLen; idx++) 
	    mpt.leafRlpHexs[idx] <== leafRlpHexs[idx];
    
    for (var idx = 0; idx < maxDepth - 1; idx++) {
	    mpt.nodePathPrefixHexLen[idx] <== nodePathPrefixHexLen[idx];
        for (var j = 0; j < maxBranchRlpHexLen; j++) 
            mpt.nodeRlpHexs[idx][j] <== nodeRlpHexs[idx][j];
        
        mpt.nodeTypes[idx] <== nodeTypes[idx];
    }
    mpt.depth <== depth;

    component final_check = IsEqual();
    final_check.in[0] <== 5;
    final_check.in[1] <== index_lt.out + block_hash.out + block_hash_check.out + tx_rlp_check + mpt.out;
    out <== final_check.out;
}