// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/Market.sol";
import "../src/Treasury.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MarketTest is Test {
    Treasury public productTreasury;
    Market public market;
    // dev: any erc20 token for testing vesting calendar on mainnet forking
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // DAI 0x6B175474E89094C44Da98b954EedeAC495271d0F;//
    // dev: quote asset for testing tokensale on mainnet is WETH
    //address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC; // binance account with 3 billions USDC
    IERC20 private constant usdc = IERC20(USDC);
    IERC20 public productToken;
    uint256 private constant productTokenCap = UINT256_MAX;


    function setUp() public {
        // ---- INIT Contracts (product, currency, treasury, market) ----
        // currency
        vm.startPrank(USDC_WHALE);
        usdc.transfer(address(this), 5000 * 1e6);
        vm.stopPrank();
        // product
        productToken = new ProductToken(productTokenCap);
        // treasury
        productTreasury = new Treasury(address(productToken));
        productToken.transfer(address(productTreasury), productTokenCap);
        // market
        market = new Market(address(usdc), address(productTreasury));

    }

    function testSaleAndVesting() public {
        // set-up vesting template in market contract
        market.deployMarket();
        /*    function deployMarket(uint256 _price,
                       uint256 _minOrderSize,
                       uint256 _maxOrderSize,
                       uint256 _tgeRatio, 
                       uint256 _start,
                       uint256 _cliff,
                       uint256 _duration,
                       uint256 _slicePeriod,
                       bool _revocable,
                       bool _permisionLess
        */
        // buy tokens from market contract
        //buy(uint256 _market, uint256 _amount, address _benefeciary) 
        usdc.approve(address(market), market.calculateOrderPrice(0, 10e4));
        market.buy(0, 10e4, address(this));
        // check tge tokens
        console.log(productToken.balanceOf(address(this)));
        // check vesting calendar

    }

}

contract ProductToken is ERC20 {
    constructor(uint256 _cap) ERC20("Product", "PTK") {
        _mint(msg.sender, _cap);
    }
}