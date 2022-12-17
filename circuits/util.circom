pragma circom 2.0.0;

template Hex2Num(hexLength) {
    signal input in[hexLength];
    var sum;
    for (var i = hexLength - 1; i >= 0; i--) {
        sum += in[i] * (16 ** (hexLength - 1 - i));
    }
    signal output out;
    out <== sum;
}