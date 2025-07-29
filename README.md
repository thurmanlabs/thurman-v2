# Thurman Protocol

Thurman is a decentralized lending protocol that enables permissioned lending pools with asynchronous deposits and withdrawals. It provides flexible lending solutions with support for any ERC20 token through dynamic decimal handling.

## Protocol Overview

### Core Components

1. **PoolManager**
   - Central contract that manages all lending pools
   - Handles deposit/withdrawal requests and fulfillment
   - Controls pool access and permissions
   - Manages loan creation and repayment processing

2. **ERC7540Vault**
   - Implementation of EIP-7540 for asynchronous deposits/withdrawals
   - Supports any ERC20 token with dynamic decimal handling
   - Manages user vault data and share accounting
   - Handles loan initialization and batch repayment processing

3. **SToken**
   - Represents shares in the lending pool
   - Implements scaled balances for accurate yield tracking
   - Handles rebasing logic for yield distribution
   - Supports dynamic decimal conversion for underlying assets

4. **LoanManager**
   - Manages loan creation and repayment logic
   - Implements precise interest calculations with dynamic decimals
   - Handles loan state management and payment processing

### Key Features

- **Universal Token Support**: Works with any ERC20 token (USDC, DAI, ETH, etc.)
- **Dynamic Decimal Handling**: Automatic conversion between token decimals and WAD format
- **Asynchronous Operations**: Deposits and withdrawals with request/fulfill pattern
- **Permissioned Lending**: Controlled access through operator-based permissions
- **Batch Operations**: Efficient batch loan creation and repayment
- **Precise Interest Calculation**: Accurate interest computation with proper decimal handling
- **Scalable Architecture**: Modular design for easy extension and maintenance

## Technical Architecture

### Dynamic Decimals Implementation

The protocol now supports any ERC20 token regardless of its decimal places:

- **USDC**: 6 decimals
- **DAI/ETH**: 18 decimals  
- **Any other token**: Automatic detection and handling

```solidity
// Automatic decimal conversion in calculations
uint256 balanceWad = WadRayMath.toWad(remainingBalance, assetDecimals);
uint256 interestWad = WadRayMath.wadMul(balanceWad, monthlyRate);
uint256 interest = WadRayMath.fromWad(interestWad, assetDecimals);
```

### Core Math Libraries

- **WadRayMath**: Fixed-point arithmetic with decimal conversion helpers
- **LoanMath**: Interest calculation with dynamic decimal support
- **MathUtils**: Common mathematical utilities

## Development Setup

### Prerequisites

- Node.js v18+ 
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
BASE_MAINNET_RPC_URL=your_base_mainnet_rpc_url
BASE_SEPOLIA_RPC_URL=your_base_sepolia_rpc_url
MAINNET_PRIVATE_KEY=your_mainnet_private_key
PRIVATE_KEY=your_private_key
BASESCAN_API_KEY=your_basescan_api_key
```

### Testing

Run all tests:
```bash
npx hardhat test
```

Run specific test file:
```bash
npx hardhat test test/user-flow.test.ts
```

Run tests with gas reporting:
```bash
REPORT_GAS=true npx hardhat test
```

### Test Structure

The test suite has been streamlined for efficiency:

- **`user-flow.test.ts`**: Comprehensive end-to-end testing covering all core functionality
- **`basic-setup.test.ts`**: Simple deployment verification
- **`helpers/`**: Test utilities and setup functions

### Contract Verification

Verify contracts on Basescan:
```bash
npx hardhat verify --network base DEPLOYED_CONTRACT_ADDRESS constructor_argument_1
```

## Recent Major Updates

### v2.0 Refactor Highlights

1. **Dynamic Decimal Support**
   - Universal token compatibility
   - Automatic decimal conversion
   - Precise interest calculations

2. **Simplified Architecture**
   - Removed Aave V3 dependency
   - Streamlined token flow
   - Improved gas efficiency

3. **Enhanced Testing**
   - Comprehensive user flow tests
   - Removed redundant test files
   - Faster test execution

4. **Improved Math Libraries**
   - Fixed WAD/RAY conversion issues
   - Added decimal conversion helpers
   - More accurate interest calculations

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the GPL-2.0 License - see the [LICENSE](LICENSE) file for details.
