# Uniswap-Sushiswap Arbitrage Bot

A smart contract-based arbitrage bot that automatically detects and executes profitable arbitrage opportunities between Uniswap V2 and Sushiswap DEXes. The contract ensures all operations are profitable by validating price differences against trading fees before execution.

## Features

- **Automated Arbitrage Detection**: Automatically compares prices between Uniswap and Sushiswap
- **Profitability Validation**: Ensures arbitrage opportunities are profitable after accounting for all fees (0.6% total: 0.3% per swap)
- **Secure Operations**: 
  - Reentrancy protection on all state-changing functions
  - Owner-only access controls
  - Comprehensive input validation
- **Event Logging**: Emits events for deposits, withdrawals, and arbitrage executions
- **Gas Optimized**: Efficient price comparison and swap execution

## Prerequisites

- Python 3.7+
- Node.js and npm (for Ganache)
- An Ethereum wallet (MetaMask recommended)
- Infura account (free tier available)

## Installation & Setup

### 1. Install Brownie

Brownie is a Python framework for smart contract development, testing, and deployment. It's similar to Hardhat but uses Python for scripts.

**Recommended installation (using pipx):**
```bash
pip install --user pipx
pipx ensurepath
# Restart your terminal after this
pipx install eth-brownie
```

**Alternative installation (using pip):**
```bash
pip install eth-brownie
```

### 2. Install Ganache CLI

Ganache is used for local blockchain development and testing:
```bash
npm install -g ganache-cli
```

### 3. Clone the Repository

```bash
git clone https://github.com/kaymen99/uniswap-sushiswap-arbitrage.git
cd uniswap-sushiswap-arbitrage
```

### 4. Configure Environment Variables

Create a `.env` file in the project root with your credentials:

```env
PRIVATE_KEY=<YOUR_PRIVATE_KEY>
WEB3_INFURA_PROJECT_ID=<YOUR_INFURA_PROJECT_ID>
```

**⚠️ Security Note**: Never commit your `.env` file to version control. It's already included in `.gitignore`.

**How to get your credentials:**
- **PRIVATE_KEY**: Export from MetaMask or your Ethereum wallet (Settings → Security & Privacy → Show Private Key)
- **WEB3_INFURA_PROJECT_ID**: Sign up at [Infura](https://infura.io) (free account available)

## Usage

### Running Arbitrage on Mainnet Fork

For testing purposes, you can run arbitrage on a mainnet fork:

```bash
brownie run scripts/arbitrage.py --network=mainnet-fork
```

This will:
1. Deploy the SimpleArbitrage contract
2. Get WETH for testing (if on fork)
3. Deposit 5 WETH into the contract
4. Execute arbitrage if a profitable opportunity exists

### Running on Testnet (Kovan)

To deploy and test on Kovan testnet:

```bash
brownie run scripts/arbitrage.py --network=kovan
```

**Note**: Make sure you have testnet ETH in your wallet for gas fees.

### Getting WETH

To convert ETH to WETH for testing:

```bash
brownie run scripts/get_weth.py --network=mainnet-fork
```

## Testing

The project includes comprehensive tests for all contract functions.

### Run All Tests

```bash
brownie test
```

### Run Specific Test

```bash
brownie test -k <function_name>
```

### Available Tests

- `test_deploy`: Verifies contract deployment and initialization
- `test_deposit`: Tests WETH deposit functionality
- `test_withdraw`: Tests WETH withdrawal functionality
- `test_make_arbitrage`: Tests arbitrage execution (reverts if not profitable)

## Project Structure

```
uniswap-sushiswap-arbitrage/
├── contracts/
│   └── SimpleArbitrage.sol    # Main arbitrage contract
├── interfaces/
│   ├── IERC20.sol             # ERC20 token interface
│   ├── IUniswapV2Router02.sol # Uniswap router interface
│   └── IWeth.sol              # WETH interface
├── scripts/
│   ├── arbitrage.py           # Main arbitrage execution script
│   ├── get_weth.py            # WETH conversion helper
│   └── helper_scripts.py      # Utility functions
├── tests/
│   └── test_simple_arbitrage.py  # Contract tests
├── brownie-config.yaml        # Brownie configuration
└── README.md                  # This file
```

## How It Works

### Arbitrage Strategy

1. **Price Comparison**: The contract compares WETH/DAI prices between Uniswap and Sushiswap
2. **Profitability Check**: Validates that the price difference exceeds trading fees (0.6% total)
3. **Execution**: 
   - If Uniswap has higher price: Sell WETH on Uniswap → Buy WETH on Sushiswap
   - If Sushiswap has higher price: Sell WETH on Sushiswap → Buy WETH on Uniswap
4. **Profit Tracking**: Updates the contract's WETH balance with the arbitrage profit

### Key Functions

- **`deposit(uint256 amount)`**: Deposit WETH into the contract for arbitrage
- **`withdraw(uint256 amount)`**: Withdraw WETH from the contract
- **`makeArbitrage()`**: Execute arbitrage if profitable opportunity exists

### Security Features

- **Reentrancy Protection**: All state-changing functions are protected against reentrancy attacks
- **Owner-Only Access**: Only the contract owner can deposit, withdraw, and execute arbitrage
- **Input Validation**: All functions validate inputs to prevent invalid operations
- **Profitability Guarantee**: Arbitrage only executes if guaranteed to be profitable

## Important Notes

1. **Gas Costs**: Arbitrage execution requires gas fees. Ensure you have sufficient ETH for transactions
2. **Slippage**: The contract uses a 5% slippage tolerance (95% of expected output)
3. **Price Volatility**: Prices can change between transaction submission and execution
4. **Profitability**: Arbitrage opportunities may not always exist. The contract will revert if no profitable opportunity is found
5. **Mainnet Usage**: Always test thoroughly on testnets before using on mainnet

## 🔧 Configuration

Network configurations are defined in `brownie-config.yaml`. Supported networks:

- `mainnet-fork`: Mainnet fork for testing
- `kovan`: Kovan testnet
- `ganache-local`: Local Ganache instance

Each network includes:
- Uniswap Router address
- Sushiswap Router address
- WETH token address
- DAI token address

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Disclaimer

This software is provided "as is" without warranty. Use at your own risk. Always audit smart contracts before deploying to mainnet. The authors are not responsible for any losses incurred from using this software.

## Additional Resources

- [Brownie Documentation](https://eth-brownie.readthedocs.io/)
- [Uniswap V2 Documentation](https://docs.uniswap.org/protocol/V2/introduction)
- [Sushiswap Documentation](https://docs.sushi.com/)
