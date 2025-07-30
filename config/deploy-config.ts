import { ethers } from "ethers";

export interface DeployConfig {
  network: string;
  tokens: {
    USDC: string;
    WETH: string;
  };
  decimals: {
    USDC: number;
    WETH: number;
  };
  poolSettings: {
    marginFee: string; // in ether (e.g., "0.02" for 2%)
    depositCap: string; // in token units
    maxDepositAmount: string; // maximum single deposit
    minDepositAmount: string; // minimum single deposit
    depositsEnabled: boolean;
    withdrawalsEnabled: boolean;
    borrowingEnabled: boolean;
    isPaused: boolean;
  };
  tokenNames: {
    sTokenName: string;
    sTokenSymbol: string;
    dTokenName: string;
    dTokenSymbol: string;
  };
  roles: {
    treasury: string; // treasury address for SToken
    admin: string; // admin address for OriginatorRegistry
  };
  verification: {
    enabled: boolean;
    delay: number; // in milliseconds
  };
}

export const deployConfigs: Record<string, DeployConfig> = {
  hardhat: {
    network: "hardhat",
    tokens: {
      USDC: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", // Base mainnet USDC (since hardhat forks Base)
      WETH: "0x4200000000000000000000000000000000000006"  // Base mainnet WETH
    },
    decimals: {
      USDC: 6,
      WETH: 18
    },
    poolSettings: {
      marginFee: "0.02", // 2%
      depositCap: "1000000000", // 1B USDC
      maxDepositAmount: "100000000", // 100M USDC
      minDepositAmount: "1000000", // 1M USDC
      depositsEnabled: true,
      withdrawalsEnabled: true,
      borrowingEnabled: true,
      isPaused: false
    },
    tokenNames: {
      sTokenName: "Thurman USDC Shares",
      sTokenSymbol: "sUSDC",
      dTokenName: "Thurman USDC Debt",
      dTokenSymbol: "dUSDC"
    },
    roles: {
      treasury: "", // Will be set to deployer address
      admin: "" // Will be set to deployer address
    },
    verification: {
      enabled: false, // No verification on hardhat
      delay: 0
    }
  },
  localhost: {
    network: "localhost",
    tokens: {
      USDC: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", // Base mainnet USDC (for localhost testing)
      WETH: "0x4200000000000000000000000000000000000006"  // Base mainnet WETH
    },
    decimals: {
      USDC: 6,
      WETH: 18
    },
    poolSettings: {
      marginFee: "0.02",
      depositCap: "1000000000",
      maxDepositAmount: "100000000",
      minDepositAmount: "1000000",
      depositsEnabled: true,
      withdrawalsEnabled: true,
      borrowingEnabled: true,
      isPaused: false
    },
    tokenNames: {
      sTokenName: "Thurman USDC Shares",
      sTokenSymbol: "sUSDC",
      dTokenName: "Thurman USDC Debt",
      dTokenSymbol: "dUSDC"
    },
    roles: {
      treasury: "",
      admin: ""
    },
    verification: {
      enabled: false, // No verification on localhost
      delay: 0
    }
  },
  baseSepolia: {
    network: "baseSepolia",
    tokens: {
      USDC: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
      WETH: "0x4200000000000000000000000000000000000006"
    },
    decimals: {
      USDC: 6,
      WETH: 18
    },
    poolSettings: {
      marginFee: "0.02",
      depositCap: "1000000000",
      maxDepositAmount: "100000000",
      minDepositAmount: "1000000",
      depositsEnabled: true,
      withdrawalsEnabled: true,
      borrowingEnabled: true,
      isPaused: false
    },
    tokenNames: {
      sTokenName: "Thurman USDC Shares",
      sTokenSymbol: "sUSDC",
      dTokenName: "Thurman USDC Debt",
      dTokenSymbol: "dUSDC"
    },
    roles: {
      treasury: "",
      admin: ""
    },
    verification: {
      enabled: true, // Verification enabled on testnet
      delay: 10000
    }
  },
  base: {
    network: "base",
    tokens: {
      USDC: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
      WETH: "0x4200000000000000000000000000000000000006"
    },
    decimals: {
      USDC: 6,
      WETH: 18
    },
    poolSettings: {
      marginFee: "0.02",
      depositCap: "1000000000",
      maxDepositAmount: "100000000",
      minDepositAmount: "1000000",
      depositsEnabled: true,
      withdrawalsEnabled: true,
      borrowingEnabled: true,
      isPaused: false
    },
    tokenNames: {
      sTokenName: "Thurman USDC Shares",
      sTokenSymbol: "sUSDC",
      dTokenName: "Thurman USDC Debt",
      dTokenSymbol: "dUSDC"
    },
    roles: {
      treasury: "",
      admin: ""
    },
    verification: {
      enabled: true, // Verification enabled on mainnet
      delay: 15000
    }
  },
  mainnet: {
    network: "mainnet",
    tokens: {
      USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    },
    decimals: {
      USDC: 6,
      WETH: 18
    },
    poolSettings: {
      marginFee: "0.02",
      depositCap: "1000000000",
      maxDepositAmount: "100000000",
      minDepositAmount: "1000000",
      depositsEnabled: true,
      withdrawalsEnabled: true,
      borrowingEnabled: true,
      isPaused: false
    },
    tokenNames: {
      sTokenName: "Thurman USDC Shares",
      sTokenSymbol: "sUSDC",
      dTokenName: "Thurman USDC Debt",
      dTokenSymbol: "dUSDC"
    },
    roles: {
      treasury: "",
      admin: ""
    },
    verification: {
      enabled: true, // Verification enabled on mainnet
      delay: 20000
    }
  }
};

export function getDeployConfig(network: string): DeployConfig {
  const config = deployConfigs[network];
  if (!config) {
    throw new Error(`No deployment configuration found for network: ${network}`);
  }
  return config;
}

export function isDevelopmentChain(network: string): boolean {
  return ["hardhat", "localhost"].includes(network);
}

export function isTestnet(network: string): boolean {
  return ["baseSepolia", "sepolia", "goerli"].includes(network);
}

export function isMainnet(network: string): boolean {
  return ["mainnet", "base", "polygon"].includes(network);
}

export function shouldVerifyContracts(network: string): boolean {
  // Only verify on actual blockchain networks (testnet/mainnet), not development networks
  return isTestnet(network) || isMainnet(network);
} 