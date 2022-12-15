import { ethers } from "ethers";

// 2. Define network configurations
const rpc = {
  bsc: {
    name: "bsc",
    rpc: "https://bsc-dataseed1.binance.org/",
    chainId: 56,
  },

  bscTest: {
    name: "bscTest",
    rpc: "https://data-seed-prebsc-1-s1.binance.org:8545/",
    chainId: 97,
  },

  fuji: {
    name: "fuji",
    rpc: "https://rpc.ankr.com/avalanche_fuji",
    chainId: 43113,
  },
};

// 3. Create ethers provider
export const bscProvider = new ethers.providers.StaticJsonRpcProvider(
  rpc.bsc.rpc,
  {
    chainId: rpc.bsc.chainId,
    name: rpc.bsc.name,
  }
);

export const bscTestProvider = new ethers.providers.StaticJsonRpcProvider(
  rpc.bscTest.rpc,
  {
    chainId: rpc.bscTest.chainId,
    name: rpc.bscTest.name,
  }
);

export const fujiProvider = new ethers.providers.StaticJsonRpcProvider(
  rpc.fuji.rpc,
  {
    chainId: rpc.fuji.chainId,
    name: rpc.fuji.name,
  }
);
