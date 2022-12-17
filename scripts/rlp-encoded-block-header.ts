import { BigNumber, ethers } from "ethers";
import { arrayify, keccak256, serializeTransaction } from "ethers/lib/utils";
import { RLP } from "ethers/lib/utils";

import { bscProvider, bscTestProvider } from "./consts/const";

// function getRawTransaction(tx) {
//     function addKey(accum, key) {
//         if (tx[key]) { accum[key] = tx[key]; }
//         return accum;
//     }

//     // Extract the relevant parts of the transaction and signature
//     const txFields = "accessList chainId data gasPrice gasLimit maxFeePerGas maxPriorityFeePerGas nonce to type value".split(" ");
//     const sigFields = "v r s".split(" ");

//     // Seriailze the signed transaction
//     const raw = serializeTransaction(txFields.reduce(addKey, {}), sigFields.reduce(addKey, {}));

//     // Double check things went well
//     if (keccak256(raw) !== tx.hash) { throw new Error("serializing failed!"); }

//     return raw;
// }

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

    //console.log({ rawTx: getRawTransaction(block.transactions[4]) })

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
rlpEncodedBlockHeader("0xb0136154cb168adeeff82ee7596b912c7aa58731553a38ce9953582ef1f68d3b", bscTestProvider).then((v) => {
    console.log(v)
    console.log(BigNumber.from(v).toString());
    inputs = [...v.replace("0x", "")].map((char) => parseInt(char, 16)); console.log({ inputs });
    const data = JSON.stringify({ data: inputs })
    const FileSystem = require("fs");
    FileSystem.writeFile('inputs/parse-input.json', data, (error: Error) => {
        if (error) throw error;
    });

}).catch((err) => console.log(err))

//console.log({ inputs })