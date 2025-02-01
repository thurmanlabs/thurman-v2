# Thurman Protocol

Thurman is a decentralized lending protocol that enables permissioned lending pools with asynchronous deposits and withdrawals. It leverages Aave V3 for yield generation while providing an additional layer of control and flexibility for pool managers.

## Protocol Overview

### Core Components

1. **PoolManager**
   - Central contract that manages all lending pools
   - Handles deposit/withdrawal requests and fulfillment
   - Controls pool access and permissions

2. **ERC7540Vault**
   - Implementation of EIP-7540 for asynchronous deposits/withdrawals
   - Integrates with Aave V3 for yield generation
   - Manages user vault data and share accounting

3. **SToken**
   - Represents shares in the lending pool
   - Implements scaled balances for accurate yield tracking
   - Handles rebasing logic for yield distribution

### Key Features

- Asynchronous deposits and withdrawals
- Permissioned lending pools
- Yield generation through Aave V3
- Operator-based access control
- Scalable balance accounting

## Development Setup

### Prerequisites

- Node.js v16+ 
- npm or yarn
- Git

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/thurman-v2.git
cd thurman-v2
```

2. Install dependencies:
```bash
npm install
```

If you encounter peer dependency conflicts, use:
```bash
npm install --legacy-peer-deps
```

> **Note**: The `--legacy-peer-deps` flag is required due to some dependencies having conflicting peer requirements, particularly with ethers and hardhat packages. This is a known issue and doesn't affect the functionality of the project.

3. Create a `.env` file:
Fill in required environment variables:
```
POLYGON_MAINNET_RPC_URL=your_polygon_mainnet_rpc_url
POLYGON_AMOY_RPC_URL=your_polygon_amoy_rpc_url
MAINNET_PRIVATE_KEY=your_mainnet_private_key
PRIVATE_KEY=your_private_key
POLYGONSCAN_API_KEY=your_polygonscan_api_key
```

### Testing

Run all tests:
```bash
npx hardhat test
```

Run specific test file:
```bash
npx hardhat test test/poolmanager-deposit.test.ts
```

Run tests with gas reporting:
```bash
REPORT_GAS=true npx hardhat test
```

### Contract Verification

Verify contracts on Polygonscan:
```bash
npx hardhat verify --network polygon DEPLOYED_CONTRACT_ADDRESS constructor_argument_1
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the GPL-2.0 License - see the [LICENSE](LICENSE) file for details.
