def serialize_int2(val_hex):
    ret0, ret1 = 0, 0
    for idx in range(32):
        ret0 = ret0 + int(val_hex[idx], 16) * (16 ** (31 - idx))
        ret1 = ret1 + int(val_hex[32 + idx], 16) * (16 ** (31 - idx))
    return [str(ret0), str(ret1)]

res = serialize_int2('4c192662ca7e2a88003cf638e2fd81f2a632911d4f99b61c871cbe8bc0177fbb')
print(res[0])
print(res[1])