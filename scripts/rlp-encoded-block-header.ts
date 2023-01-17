import { BigNumber, ethers } from "ethers";
import { arrayify, keccak256, serializeTransaction } from "ethers/lib/utils";
import { RLP } from "ethers/lib/utils";

import {
  avaxProvider,
  bscProvider,
  bscTestProvider,
  fujiProvider,
  goerliProvider,
  polygonProvider,
} from "./consts/const";

const parseInput = (rlpString: string): object => {
  rlpString = rlpString.replace("0x", "");

  const padLen = 1112 - rlpString.length;

  if (padLen > 0) {
    rlpString += "0".repeat(padLen);
  }

  const rlpHexEncoded = [...rlpString].map((char) => parseInt(char, 16));
  console.log({ length: rlpHexEncoded.length });

  const inputs = {
    rlpHexEncoded: rlpHexEncoded,
  };

  console.log({ inputs });

  return inputs;
};

export const rlpEncodedBlockHeader = async (
  txHash: string,
  provider: ethers.providers.StaticJsonRpcProvider,
  preseal: boolean = false
): Promise<string> => {
  const tx = await provider.getTransaction(txHash);
  const block = await provider.send("eth_getBlockByHash", [
    tx.blockHash,
    false,
  ]);

  console.log({ block });

  // const blockData = JSON.stringify({ result: block });
  // const FileSystem = require("fs");
  // FileSystem.writeFile("file.json", blockData, (error: Error) => {
  //   if (error) throw error;
  // });

  const {
    parentHash: ParentHash,
    sha3Uncles: UncleHash,
    miner: Coinbase,
    stateRoot: Root,
    transactionsRoot: TxHash,
    receiptsRoot: ReceiptHash,
    logsBloom: Bloom,
    difficulty: Difficulty,
    number: Number,
    gasLimit: GasLimit,
    gasUsed: GasUsed,
    timestamp: Time,
    extraData: Extra,
    mixHash: MixDigest,
    nonce: Nonce,
    baseFeePerGas: BaseFee, // For Post 1559 blocks
    hash, // For comparison afterwards
  } = block;

  const chainId = (await provider.getNetwork()).chainId;
  let blockHeaderInputs: { [key: string]: string } = {};
  if (preseal && (chainId == 56 || chainId == 97))
    blockHeaderInputs["chainId"] = BigNumber.from("137").toHexString();
  blockHeaderInputs = {
    ...blockHeaderInputs,
    ...{
      ParentHash,
      UncleHash,
      Coinbase:
        chainId == 137 || chainId == 80001
          ? ethers.constants.AddressZero
          : Coinbase,
      Root,
      TxHash,
      ReceiptHash,
      Bloom,
      Difficulty,
      Number,
      GasLimit,
      GasUsed,
      Time,
      Extra,
      MixDigest,
      Nonce,
    },
  };

  if ("extDataHash" in block)
    blockHeaderInputs["ExtDataHash"] = block.extDataHash;

  if (BaseFee) blockHeaderInputs["BaseFee"] = BaseFee;

  if ("extDataGasUsed" in block)
    blockHeaderInputs["ExtDataGasUsed"] = block.extDataGasUsed;

  if ("blockGasCost" in block)
    blockHeaderInputs["BlockGasCost"] = block.blockGasCost;

  Object.keys(blockHeaderInputs).map((key: string) => {
    let val = blockHeaderInputs[key];

    // All 0 values for these fields must be 0x
    if (
      parseInt(val, 16) === 0 &&
      [
        "GasLimit",
        "GasUsed",
        "Time",
        "Difficulty",
        "Number",
        "ExtDataGasUsed",
        "BlockGasCost",
      ].includes(key)
    )
      val = "0x";

    if (preseal && "Extra".includes(key)) val = val.substring(0, 66);

    // Pad hex for proper Bytes parsing
    if (val.length % 2 == 1) val = val.substring(0, 2) + "0" + val.substring(2);

    blockHeaderInputs[key] = val;
  });

  console.log({
    blockHeaderInputs,
    nFields: Object.keys(blockHeaderInputs).length,
  });

  const rlpEncodedHeader = RLP.encode(Object.values(blockHeaderInputs));

  const derivedBlockHash = ethers.utils.keccak256(rlpEncodedHeader);
  console.log(`Derived: ${derivedBlockHash}`);
  console.log(`Actual: ${hash}`);
  if (!preseal && derivedBlockHash !== hash) throw new Error("Hash mismatch!");
  console.log({ rlpEncodedHeader, length: rlpEncodedHeader.length });

  return rlpEncodedHeader;
};

let inputs;
rlpEncodedBlockHeader(
  // "0xb0136154cb168adeeff82ee7596b912c7aa58731553a38ce9953582ef1f68d3b",
  // bscTestProvider,

  "0x5835dd1718bd4273cc97f85588f59fdae151567943dfc1039f6081e565869dd8",
  polygonProvider,

  // "0xcf19bde0dd10075a2590982d73bde197bd4857dab068d9319e5c8b834dae76e4",
  // fujiProvider,

  // "0xdd0b12866a3b68c7df032bfa77f1a1b14448e40ac98017ffffa90ce07e7e2e6b",
  // avaxProvider,

  // "0xaa176f4d9fca9e2d0dab3b29606dce49fb81b4d1de3fd500f34fbe4d7bccef1d",
  // goerliProvider,
  true
)
  .then((v) => {
    v = v.replace("0x", "");
    const padLen = 1112 - v.length;

    if (padLen > 0) v += "0".repeat(padLen);
    inputs = [...v].map((char) => parseInt(char, 16));
    console.log({ inputs, length: inputs.length });
    const data = JSON.stringify({ blockRlpHexs: inputs });
    const FileSystem = require("fs");
    FileSystem.writeFile("inputs/polygon-input.json", data, (error: Error) => {
      if (error) throw error;
    });
  })
  .catch((err) => console.log(err));

//console.log({ inputs })
