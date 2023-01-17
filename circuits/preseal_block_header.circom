pragma circom 2.0.2;

include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/multiplexer.circom";

include "./utils/mpt.circom";
include "./utils/rlp.circom";
include "./utils/keccak.circom";

template PolygonBlockHashHex() {
    signal input blockRlpHexs[1112];

    signal output out;
    signal output blockHashHexs[64];

    signal output numberHexLen;
    
    signal output stateRoot[64];
    signal output transactionsRoot[64];		
    signal output receiptsRoot[64];	
    signal output number[6];

    log(555555500001);
    for (var idx = 0; idx < 1112; idx++) {
        log(blockRlpHexs[idx]);
    }

    log(555555500001);
    for (var idx = 0; idx < 1112; idx++) {
        log(blockRlpHexs[idx]);
    }

    component rlp = RlpArrayCheck(
        1112, 
        16, 
        4,	      	    	  
        [64, 64, 40, 64, 64, 64, 512,  0, 0, 0, 0, 0,  0, 64, 16, 0],
		[64, 64, 40, 64, 64, 64, 512, 14, 8, 8, 8, 8, 64, 64, 18, 10]
    );

    for (var idx = 0; idx < 1112; idx++) {
    	rlp.in[idx] <== blockRlpHexs[idx];
    }

    var blockRlpHexLen = rlp.totalRlpHexLen;
    component pad = ReorderPad101Hex(1016, 1112, 1360, 13);
    pad.inLen <== blockRlpHexLen;
    for (var idx = 0; idx < 1112; idx++) {
        pad.in[idx] <== blockRlpHexs[idx];
    }

    // if leq.out == 1, use 4 rounds, else use 5 rounds
    component leq = LessEqThan(13);
    leq.in[0] <== blockRlpHexLen + 1;
    // 4 * blockSize = 1088
    leq.in[1] <== 1088;
    
    var blockSizeHex = 136 * 2;
    component keccak = Keccak256Hex(5);
    for (var idx = 0; idx < 5 * blockSizeHex; idx++) {
        keccak.inPaddedHex[idx] <== pad.out[idx];
    }
    keccak.rounds <== 5 - leq.out;

    out <== rlp.out;
    for (var idx = 0; idx < 32; idx++) {
        blockHashHexs[2 * idx] <== keccak.out[2 * idx + 1];
	    blockHashHexs[2 * idx + 1] <== keccak.out[2 * idx];
    }
    for (var idx = 0; idx < 64; idx++) {
    	stateRoot[idx] <== rlp.fields[3][idx];
    	transactionsRoot[idx] <== rlp.fields[4][idx];
    	receiptsRoot[idx] <== rlp.fields[5][idx];
    }
    numberHexLen <== rlp.fieldHexLen[8];
    for (var idx = 0; idx < 6; idx++) {
        number[idx] <== rlp.fields[8][idx];
    }

    log(out);
    for (var idx = 0; idx < 64; idx++) {
        log(blockHashHexs[idx]);
    }
    log(numberHexLen);
    for (var idx = 0; idx < 64; idx++) {
        log(stateRoot[idx]);
    }
    for (var idx = 0; idx < 64; idx++) {
        log(transactionsRoot[idx]);
    }
    for (var idx = 0; idx < 64; idx++) {
        log(receiptsRoot[idx]);
    }
    for (var idx = 0; idx < 6; idx++) {
        log(number[idx]);
    }    
}

template BscBlockHashHex() {
    signal input blockRlpHexs[1112];

    signal output out;
    signal output blockHashHexs[64];

    signal output numberHexLen;
    
    signal output stateRoot[64];
    signal output transactionsRoot[64];		
    signal output receiptsRoot[64];	
    signal output number[6];

    log(555555500001);
    for (var idx = 0; idx < 1112; idx++) {
        log(blockRlpHexs[idx]);
    }

    component rlp = RlpArrayCheck(
        1112, 
        16, 
        4,	      	    	  
        [2, 64, 64, 40, 64, 64, 64, 512,  0, 0, 0, 0, 0,  0, 64, 16],
		[8, 64, 64, 40, 64, 64, 64, 512, 14, 8, 8, 8, 8, 64, 64, 18]
    );
    for (var idx = 0; idx < 1112; idx++) {
    	rlp.in[idx] <== blockRlpHexs[idx];
    }

    var blockRlpHexLen = rlp.totalRlpHexLen;
    component pad = ReorderPad101Hex(1016, 1112, 1360, 13);
    pad.inLen <== blockRlpHexLen;
    for (var idx = 0; idx < 1112; idx++) {
        pad.in[idx] <== blockRlpHexs[idx];
    }

    // if leq.out == 1, use 4 rounds, else use 5 rounds
    component leq = LessEqThan(13);
    leq.in[0] <== blockRlpHexLen + 1;
    // 4 * blockSize = 1088
    leq.in[1] <== 1088;
    
    var blockSizeHex = 136 * 2;
    component keccak = Keccak256Hex(5);
    for (var idx = 0; idx < 5 * blockSizeHex; idx++) {
        keccak.inPaddedHex[idx] <== pad.out[idx];
    }
    keccak.rounds <== 5 - leq.out;

    out <== rlp.out;
    for (var idx = 0; idx < 32; idx++) {
        blockHashHexs[2 * idx] <== keccak.out[2 * idx + 1];
	    blockHashHexs[2 * idx + 1] <== keccak.out[2 * idx];
    }
    for (var idx = 0; idx < 64; idx++) {
    	stateRoot[idx] <== rlp.fields[4][idx];
    	transactionsRoot[idx] <== rlp.fields[5][idx];
    	receiptsRoot[idx] <== rlp.fields[6][idx];
    }
    numberHexLen <== rlp.fieldHexLen[9];
    for (var idx = 0; idx < 6; idx++) {
        number[idx] <== rlp.fields[9][idx];
    }

    log(out);
    for (var idx = 0; idx < 64; idx++) {
        log(blockHashHexs[idx]);
    }
    log(numberHexLen);
    for (var idx = 0; idx < 64; idx++) {
        log(stateRoot[idx]);
    }
    for (var idx = 0; idx < 64; idx++) {
        log(transactionsRoot[idx]);
    }
    for (var idx = 0; idx < 64; idx++) {
        log(receiptsRoot[idx]);
    }
    for (var idx = 0; idx < 6; idx++) {
        log(number[idx]);
    }    
}

