import { ethers } from "ethers";
import {
	bscProvider,
	bscTestProvider,
	fujiProvider,
	goerliProvider,
	polygonProvider,
} from "./consts/const";

const verifyRLPEncoding = async () => {
	// // polygon
	// const block = await polygonProvider.send("eth_getBlockByHash", [
	//     "0xab3dbe7398c87c2040609423161755eb3ccf133175994393028673cdabe36141",
	//     false,
	// ]);

	// // goerli
	// const block = await goerliProvider.send("eth_getBlockByHash", [
	// 	"0xe53692756caa3f50b619ab91c01fa6bc8df31387b07235eca7cc0897f3a4d425",
	// 	false,
	// ]);

	// bsc
	const block = await bscProvider.send("eth_getBlockByHash", [
	    "0x1a8b7b82ce69e3d66fc8c9ab08ea42d51388b8594b7c33d286e4ab44cd0ac119",
	    true,
	]);

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

	// Construct bytes like input to RLP encode function
	const blockHeaderInputs: { [key: string]: string } = {

		//chainId: BigNumber.from("137").toHexString(),
		ParentHash,
		UncleHash,
		Coinbase: Coinbase,
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
	};

	if (BaseFee) blockHeaderInputs["BaseFee"] = BaseFee;

	console.log({ blockHeaderInputs });

	Object.keys(blockHeaderInputs).map((key: string) => {
		let val = blockHeaderInputs[key];

		// All 0 values for these fields must be 0x
		if (
			parseInt(val, 16) === 0 &&
			["GasLimit", "GasUsed", "Time", "Difficulty", "Number"].includes(key)
		)
			val = "0x";

		if ("Extra".includes(key)) val = val.substring(0, 66);

		// Pad hex for proper Bytes parsing
		if (val.length % 2 == 1) val = val.substring(0, 2) + "0" + val.substring(2);

		blockHeaderInputs[key] = val;
	});

	const rlpEncodedHeader = ethers.utils.RLP.encode(
		Object.values(blockHeaderInputs)
	);

	const derivedBlockHash = ethers.utils.keccak256(rlpEncodedHeader);

	console.log("Block Number", Number);
	console.log("Mix hash", MixDigest);
	console.log("Result Block Hash", derivedBlockHash);
	console.log("Actual Block Hash", hash);
	console.log("=========================");
};

verifyRLPEncoding();
