// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IERC20.sol";

contract SimpleArbitrage {
    address public owner;

    address public wethAddress;
    address public daiAddress;
    address public uniswapRouterAddress;
    address public sushiswapRouterAddress;

    uint256 public arbitrageAmount;
    
    // Reentrancy guard
    bool private locked;

    enum Exchange {
        UNI,
        SUSHI,
        NONE
    }
    
    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event ArbitrageExecuted(
        Exchange indexed exchange,
        uint256 amountIn,
        uint256 amountOut,
        uint256 profit
    );

    constructor(
        address _uniswapRouterAddress,
        address _sushiswapRouterAddress,
        address _weth,
        address _dai
    ) {
        uniswapRouterAddress = _uniswapRouterAddress;
        sushiswapRouterAddress = _sushiswapRouterAddress;
        owner = msg.sender;
        wethAddress = _weth;
        daiAddress = _dai;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner can call this");
        _;
    }
    
    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    function deposit(uint256 amount) public onlyOwner nonReentrant {
        require(amount > 0, "Deposit amount must be greater than 0");
        require(
            IERC20(wethAddress).transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        arbitrageAmount += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) public onlyOwner nonReentrant {
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(amount <= arbitrageAmount, "Not enough amount deposited");
        arbitrageAmount -= amount;
        require(
            IERC20(wethAddress).transfer(msg.sender, amount),
            "Transfer failed"
        );
        emit Withdrawn(msg.sender, amount);
    }

    function makeArbitrage() public onlyOwner nonReentrant {
        require(arbitrageAmount > 0, "No funds available for arbitrage");
        uint256 amountIn = arbitrageAmount;
        Exchange result = _comparePrice(amountIn);
        require(result != Exchange.NONE, "No arbitrage opportunity found");
        
        uint256 amountOut;
        uint256 amountFinal;
        
        if (result == Exchange.UNI) {
            // sell ETH in uniswap for DAI with high price and buy ETH from sushiswap with lower price
            amountOut = _swap(
                amountIn,
                uniswapRouterAddress,
                wethAddress,
                daiAddress
            );
            amountFinal = _swap(
                amountOut,
                sushiswapRouterAddress,
                daiAddress,
                wethAddress
            );
        } else {
            // sell ETH in sushiswap for DAI with high price and buy ETH from uniswap with lower price
            amountOut = _swap(
                amountIn,
                sushiswapRouterAddress,
                wethAddress,
                daiAddress
            );
            amountFinal = _swap(
                amountOut,
                uniswapRouterAddress,
                daiAddress,
                wethAddress
            );
        }
        
        uint256 profit = amountFinal > amountIn ? amountFinal - amountIn : 0;
        arbitrageAmount = amountFinal;
        emit ArbitrageExecuted(result, amountIn, amountFinal, profit);
    }

    function _swap(
        uint256 amountIn,
        address routerAddress,
        address sell_token,
        address buy_token
    ) internal returns (uint256) {
        IERC20(sell_token).approve(routerAddress, amountIn);

        uint256 amountOutMin = (_getPrice(
            routerAddress,
            sell_token,
            buy_token,
            amountIn
        ) * 95) / 100;

        address[] memory path = new address[](2);
        path[0] = sell_token;
        path[1] = buy_token;

        uint256 amountOut = IUniswapV2Router02(routerAddress)
            .swapExactTokensForTokens(
                amountIn,
                amountOutMin,
                path,
                address(this),
                block.timestamp
            )[1];
        return amountOut;
    }

    function _comparePrice(uint256 amount) internal view returns (Exchange) {
        uint256 uniswapPrice = _getPrice(
            uniswapRouterAddress,
            wethAddress,
            daiAddress,
            amount
        );
        uint256 sushiswapPrice = _getPrice(
            sushiswapRouterAddress,
            wethAddress,
            daiAddress,
            amount
        );

        // we try to sell ETH with higher price and buy it back with low price to make profit
        if (uniswapPrice > sushiswapPrice) {
            require(
                _checkIfArbitrageIsProfitable(
                    amount,
                    uniswapPrice,
                    sushiswapPrice
                ),
                "Arbitrage not profitable"
            );
            return Exchange.UNI;
        } else if (uniswapPrice < sushiswapPrice) {
            require(
                _checkIfArbitrageIsProfitable(
                    amount,
                    sushiswapPrice,
                    uniswapPrice
                ),
                "Arbitrage not profitable"
            );
            return Exchange.SUSHI;
        } else {
            return Exchange.NONE;
        }
    }

    function _checkIfArbitrageIsProfitable(
        uint256 amountIn,
        uint256 higherPrice,
        uint256 lowerPrice
    ) internal pure returns (bool) {
        // Uniswap & Sushiswap have 0.3% fee for every exchange
        // higherPrice = DAI received for selling amountIn WETH (already includes 0.3% fee)
        // lowerPrice = DAI received for selling amountIn WETH on other exchange (already includes 0.3% fee)
        
        require(higherPrice > lowerPrice, "Invalid price comparison");
        
        // Price difference ratio: how much more DAI we get from the higher price exchange
        // This represents the arbitrage opportunity before fees
        uint256 priceDifference = higherPrice - lowerPrice;
        
        // Calculate minimum required price difference to cover fees
        // Each swap has 0.3% fee, so we lose 0.6% total
        // We need the price difference to be at least 0.6% of the lower price to break even
        // Plus a small buffer for gas and slippage
        
        // Minimum required difference: 0.6% of lowerPrice (to cover fees) + 0.1% buffer
        uint256 minRequiredDifference = (lowerPrice * 7) / 1000; // 0.7% buffer
        
        // Check if price difference is sufficient
        // Also ensure we get more WETH back than we put in
        // The ratio higherPrice/lowerPrice should be > 1.006 (0.6% fees)
        if (priceDifference < minRequiredDifference) {
            return false;
        }
        
        // Additional check: ensure the price ratio accounts for fees
        // If higherPrice/lowerPrice > 1.006, arbitrage is profitable
        // This is equivalent to: higherPrice * 1000 > lowerPrice * 1006
        return (higherPrice * 1000) > (lowerPrice * 1006);
    }

    function _getPrice(
        address routerAddress,
        address sell_token,
        address buy_token,
        uint256 amount
    ) internal view returns (uint256) {
        address[] memory pairs = new address[](2);
        pairs[0] = sell_token;
        pairs[1] = buy_token;
        uint256 price = IUniswapV2Router02(routerAddress).getAmountsOut(
            amount,
            pairs
        )[1];
        return price;
    }
}
