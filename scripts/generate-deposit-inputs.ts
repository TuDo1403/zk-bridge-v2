import { BigNumber, ethers, utils, providers } from "ethers";
import { arrayify, hexlify, RLP } from "ethers/lib/utils";
import {
  BranchNode,
  ExtensionNode,
  LeafNode,
  Trie,
  TrieNode,
} from "@ethereumjs/trie";
import { bscProvider, bscTestProvider } from "./consts/const";

const byteReverse = (binStr: string): number[] => {
  return [...Buffer.from(binStr, "binary").reverse()];
};

function hexToInt(arr: number[]): BigNumber {
  const hexString = arr.map((x) => x.toString(16)).join("");
  return BigNumber.from(hexString);
}

function serializeInt2(valHex: string): string[] {
  const ret = [BigNumber.from(0), BigNumber.from(0)];
  for (let i = 0; i < 32; i++) {
    ret[0] = ret[0].add(
      BigNumber.from(parseInt(valHex[i], 16)).mul(
        BigNumber.from(16).pow(31 - i)
      )
    );
    ret[1] = ret[1].add(
      BigNumber.from(parseInt(valHex[32 + i], 16)).mul(
        BigNumber.from(16).pow(31 - i)
      )
    );
  }
  return ret.map((x) => x.toString());
}

function constructMpt(d: Record<string, string>): [Trie, any] {
  const storage = {};
  const trie = new Trie(storage);

  for (const key of Object.keys(d)) {
    const k = Buffer.from(key, "hex");
    const value = Buffer.from(d[key], "hex");
    trie.put(k, value);
  }

  return [trie, storage];
}

function getMPTProof(
  storage: any,
  proof: any[],
  node: TrieNode,
  path: string
): any[] {
  // Initialize the loop variables
  let currentNode: TrieNode = node;
  let currentPath: string = path;

  // Keep looping until there is no path left or we reach a leaf node
  while (currentPath.length > 0 && !(currentNode instanceof LeafNode)) {
    // Add the current node to the proof array
    proof.push(currentNode);
    // If the current node is an extension, consume the common path and update the current node and path
    if (currentNode instanceof ExtensionNode) {
      currentPath = currentPath.slice(currentNode.keyLength());
      currentNode = storage[currentNode._nibbles[0]];
    }
    // If the current node is a branch, consume the first character of the path and update the current node and path
    else if (currentNode instanceof BranchNode) {
      currentPath = currentPath.slice(1);
      currentNode = storage[currentNode.getChildren()[0][0]];
    }
  }
  // Add the final node to the proof array and return the result
  proof.push(currentNode);
  return proof;
}

async function getRawTransaction(
  provider: ethers.providers.JsonRpcProvider,
  txHash: string
): Promise<string> {
  // Get the transaction object
  const tx = await provider.send("eth_getTransactionByHash", [txHash]);
  //const tx = await provider.getTransaction(txHash);
  console.log({ tx });

  const { nonce, gasPrice, gasLimit, to, value, data, v, r, s } = tx;
  const inputs: { [key: string]: string } = {
    nonce,
    gasPrice,
    gasLimit,
    to,
    value,
    data,
    v,
    r,
    s,
  };

  console.log({ inputs });

  Object.keys(inputs).map((key: string) => {
    let val = inputs[key];

    if (parseInt(val, 16) === 0) val = "0x";

    if (val.length % 2 == 1) val = val.substring(0, 2) + "0" + val.substring(2);

    console.log({ key, val });
    inputs[key] = val;
  });

  console.log({ inputs });

  // Get the raw transaction data as a string
  const rawTx = RLP.encode(Object.values(inputs));
  console.log({ rawTx });
  return hexlify(rawTx);
}

async function getTransactionRoot(
  provider: ethers.providers.JsonRpcProvider,
  transactions: Transaction[]
): Promise<string> {
  const trie = new Trie();
  for (const transaction of transactions) {
    const rlpEncodedTransaction = await getRawTransaction(
      provider,
      transaction.hash
    );
    trie.put(
      Buffer.from(arrayify(hexlify(transaction.transactionIndex))),
      Buffer.from(arrayify(rlpEncodedTransaction))
    );
  }
  return hexlify(trie.root());
}

interface Transaction {
  hash: string;
  nonce: number | string;
  blockHash: string;
  blockNumber: number | string;
  transactionIndex: number | string;
  from: string;
  to: string;
  value: string | number;
  gasPrice: string | number;
  gas: string | number;
  input: string;
  v: string | number;
  r: string | number;
  s: string | number;
}

async function main() {
  const block = await bscProvider.send("eth_getBlockByHash", [
    "0x1a8b7b82ce69e3d66fc8c9ab08ea42d51388b8594b7c33d286e4ab44cd0ac119",
    true,
  ]);

  console.log({ block });

  const transactions: Transaction[] = block.transactions;
  const txRoot = await getTransactionRoot(bscProvider, transactions);

  console.log(block.transactionsRoot);
  console.log(txRoot);
}

main();
