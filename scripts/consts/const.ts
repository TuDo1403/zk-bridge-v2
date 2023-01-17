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

  avax: {
    name: "avalanche",
    rpc: "https://ava-mainnet.public.blastapi.io/ext/bc/C/rpc",
    chainId: 43114,
  },

  fuji: {
    name: "fuji",
    rpc: "https://rpc.ankr.com/avalanche_fuji",
    chainId: 43113,
  },

  moonbase: {
    name: "moonbase-alpha",
    rpc: "https://rpc.api.moonbase.moonbeam.network",
    chainId: 1287,
  },

  goerli: {
    name: "goerli",
    rpc: "https://rpc.ankr.com/eth_goerli",
    chainId: 5,
  },

  polygon: {
    name: "poligon",
    rpc: "https://polygon-rpc.com",
    chainId: 137,
  },
};

export const polygonProvider = new ethers.providers.StaticJsonRpcProvider(
  rpc.polygon.rpc,
  {
    chainId: rpc.polygon.chainId,
    name: rpc.polygon.name,
  }
);

export const goerliProvider = new ethers.providers.StaticJsonRpcProvider(
  rpc.goerli.rpc,
  {
    chainId: rpc.goerli.chainId,
    name: rpc.goerli.name,
  }
);

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

export const moonbaseProvider = new ethers.providers.StaticJsonRpcProvider(
  rpc.moonbase.rpc,
  { chainId: rpc.moonbase.chainId, name: rpc.moonbase.name }
);

export const avaxProvider = new ethers.providers.StaticJsonRpcProvider(
  rpc.avax.rpc,
  {
    chainId: rpc.avax.chainId,
    name: rpc.avax.name,
  }
);
