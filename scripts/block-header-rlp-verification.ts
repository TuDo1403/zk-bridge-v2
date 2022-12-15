import { ethers } from "ethers";
import { bscProvider, bscTestProvider } from "./consts/const";

const verifyRLPEncoding = async () => {
    const provider = bscTestProvider;
    const tx = await provider.getTransaction(
        "0x49c148776c29a747a0a545af4b1c948690ed9a0e60f8e9aa60e3d5feb121c8fe"
    );

    console.log({ tx })

    const block = await provider.send("eth_getBlockByHash", [
        "0x2a0b63b96dcd54a60a8e5b7bad1d2950cef9599ca25ca94d9fc2d2923403d7e9",
        true,
    ]);

    console.log({ block })

    const {
        parentHash,
        sha3Uncles,
        miner, // Coinbase
        stateRoot,
        transactionsRoot,
        receiptsRoot,
        logsBloom,
        difficulty,
        number,
        gasLimit,
        gasUsed,
        timestamp,
        extraData,
        mixHash,
        nonce,
        baseFeePerGas, // For Post 1559 blocks
        hash, // For comparison afterwards
    } = block;

    // Construct bytes like input to RLP encode function
    const blockHeaderInputs: { [key: string]: string } = {
        parentHash,
        sha3Uncles,
        miner, // Coinbase
        stateRoot,
        transactionsRoot,
        receiptsRoot,
        logsBloom,
        difficulty,
        number,
        gasLimit,
        gasUsed,
        timestamp,
        extraData,
        mixHash,
        nonce,
    };

    console.log({ blockHeaderInputs })

    // const LONDON_HARDFORK_BLOCK = 12965000;
    // if (number > LONDON_HARDFORK_BLOCK) {
    //     blockHeaderInputs["baseFeePerGas"] = baseFeePerGas;
    // }



    Object.keys(blockHeaderInputs).map((key: string) => {
        let val = blockHeaderInputs[key];

        // All 0 values for these fields must be 0x
        if (["gasLimit", "gasUsed", "time", "difficulty", "number"].includes(key)) {
            if (parseInt(val, 16) === 0) {
                val = "0x";
            }
        }

        // Pad hex for proper Bytes parsing
        if (val.length % 2 == 1) {
            val = val.substring(0, 2) + "0" + val.substring(2);
        }

        blockHeaderInputs[key] = val;
    });

    const rlpEncodedHeader = ethers.utils.RLP.encode(
        Object.values(blockHeaderInputs)
    );

    console.log({ rlpEncodedHeader })
    const derivedBlockHash = ethers.utils.keccak256(rlpEncodedHeader);

    console.log("Block Number", number);
    console.log("Mix hash", mixHash);
    console.log("Derived Block Hash", derivedBlockHash);
    console.log("Actual Block Hash", hash);
    console.log("=========================");

    if (derivedBlockHash === hash) {
        console.log("SUCCESS! Derived matches expected", derivedBlockHash);
    } else {
        throw new Error(
            `Derived ${derivedBlockHash} DOES NOT match expected ${hash}`
        );
    }
};

verifyRLPEncoding();
