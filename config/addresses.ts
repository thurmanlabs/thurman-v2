export const ADDRESSES = {
    mainnet: {
        tokens: {
            USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
        },
        whales: {
            USDC: "0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503"
        }
    },
    polygon: {
        tokens: {
            USDC: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
            WMATIC: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"
        },
        whales: {
            USDC: "0xAf56edF88c429F1D6858f9E47731FF53F6d34D0C"
        }
    },
    baseSepolia: {
        tokens: {
            USDC: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
            WETH: "0x4200000000000000000000000000000000000006"
        },
        whales: {
            USDC: "0x0000000000000000000000000000000000000000"
        }
    },
    base: {
        tokens: {
            USDC: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
            WETH: "0x4200000000000000000000000000000000000006"
        },
        whales: {
            USDC: "0x770B6046463aB5f6F767c22Ebcd9a49d9f8Cdca0"
        }
    }
} as const;


export function getAddresses(network: keyof typeof ADDRESSES) {
    return ADDRESSES[network];
}