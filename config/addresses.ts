export const ADDRESSES = {
    mainnet: {
        aave: {
            pool: "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2",
            addressesProvider: "0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e"
        },
        tokens: {
            USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
            aUSDC: "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c"
        },
        whales: {
            USDC: "0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503"
        }
    },
    polygon: {
        aave: {
            pool: "0x794a61358D6845594F94dc1DB02A252b5b4814aD",
            addressesProvider: "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb"
        },
        tokens: {
            USDC: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359",
            WMATIC: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
            aUSDC: "0xA4D94019934D8333Ef880ABFFbF2FDd611C762BD"
        },
        whales: {
            USDC: "0xAf56edF88c429F1D6858f9E47731FF53F6d34D0C"
        }
    }
} as const;


export function getAddresses(network: keyof typeof ADDRESSES) {
    return ADDRESSES[network];
}