import { ethers } from "ethers";
import { RLP } from "ethers/lib/utils";

import { bscProvider, bscTestProvider } from "./consts/const";

const parseInput = (rlpString: string): object => {
    rlpString = rlpString.replace("0x", "")

    const padLen = 1112 - rlpString.length

    if (padLen > 0) {
        rlpString += "0".repeat(padLen)
    }

    const rlpHexEncoded = [...rlpString].map((char) => parseInt(char, 16))
    console.log({ length: rlpHexEncoded.length })

    const inputs = {
        rlpHexEncoded: rlpHexEncoded
    }

    console.log({ inputs })

    return inputs
}

export const rlpEncodedBlockHeader = async (txHash: string, provider: ethers.providers.StaticJsonRpcProvider): Promise<string> => {
    const tx = await provider.getTransaction(txHash)
    console.log({ tx })
    const block = await provider.send("eth_getBlockByHash", [tx.blockHash, true])

    const blockData = JSON.stringify({ result: block })
    const FileSystem = require("fs");
    FileSystem.writeFile('file.json', blockData, (error: Error) => {
        if (error) throw error;
    });

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

    const rlpHeader = RLP.encode(Object.values(blockHeaderInputs))
    console.log({ rlpHeader })

    return rlpHeader
}

let inputs
rlpEncodedBlockHeader("0x49c148776c29a747a0a545af4b1c948690ed9a0e60f8e9aa60e3d5feb121c8fe", bscProvider).then((v) => inputs = parseInput(v)).catch((err) => console.log(err))
