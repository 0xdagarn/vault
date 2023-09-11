// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { Token } from "../src/Token.sol";
import { PriceFeed } from "../src/PriceFeed.sol";
import { Vault } from "../src/Vault.sol";

contract VaultTest is Test {
    uint256 internal constant BTC_PRICE = 60_000;
    uint256 internal constant ETH_PRICE = 1_500;
    uint256 internal constant USDC_PRICE = 1;

    uint256 internal constant BTC_DECIMAL = 8;
    uint256 internal constant ETH_DECIMAL = 18;
    uint256 internal constant USDC_DECIMAL = 6;
    uint256 internal constant CHAINLINK_PRICE_DECIMAL = 8;

    uint256 internal BASIS_FACTOR;
    uint256 internal BUYING_POWER_DECIMAL;

    Token internal eth;
    Token internal btc;
    Token internal usdc;

    PriceFeed internal btcPriceFeed;
    PriceFeed internal ethPriceFeed;
    PriceFeed internal usdcPriceFeed;

    Vault internal vault;

    address internal alice;
    uint256 internal amount;

    /// helper functions
    function expandDecimal(uint256 _amount, uint256 decimal) internal pure returns (uint256) {
        return _amount * 10 ** decimal;
    }

    function setUp() public {
        alice = address(0x01);
        amount = 123;

        {
            btc = new Token("Bitcoin", "BTC");
            btcPriceFeed = new PriceFeed();

            eth = new Token("Ethereum", "ETH");
            ethPriceFeed = new PriceFeed();

            usdc = new Token("USD Coin", "USDC");
            usdcPriceFeed = new PriceFeed();
        }

        vault = new Vault();
        BASIS_FACTOR = vault.BASIS_FACTOR();
        BUYING_POWER_DECIMAL = vault.BUYING_POWER_DECIMAL();
    }

    function test_setToken() public {
        vault.setToken(address(btc), BTC_DECIMAL, 8, false, address(btcPriceFeed));
        assertEq(vault.allowedTokenConfig(address(btc)).decimal, 8);
        assertEq(vault.allowedTokenConfig(address(btc)).factor, 8);
        assertEq(vault.allowedTokenConfig(address(btc)).isStable, false);
        assertEq(vault.allowedTokenConfig(address(btc)).priceFeed, address(btcPriceFeed));

        vault.setToken(address(eth), ETH_DECIMAL, 7, false, address(ethPriceFeed));
        assertEq(vault.allowedTokenConfig(address(eth)).decimal, 18);
        assertEq(vault.allowedTokenConfig(address(eth)).factor, 7);
        assertEq(vault.allowedTokenConfig(address(eth)).isStable, false);
        assertEq(vault.allowedTokenConfig(address(eth)).priceFeed, address(ethPriceFeed));

        vault.setToken(address(usdc), USDC_DECIMAL, 10, true, address(usdcPriceFeed));
        assertEq(vault.allowedTokenConfig(address(usdc)).decimal, 6);
        assertEq(vault.allowedTokenConfig(address(usdc)).factor, 10);
        assertEq(vault.allowedTokenConfig(address(usdc)).isStable, true);
        assertEq(vault.allowedTokenConfig(address(usdc)).priceFeed, address(usdcPriceFeed));
    }

    function test_clearToken() public {
        vault.setToken(address(btc), BTC_DECIMAL, 8, false, address(btcPriceFeed));
        vault.setToken(address(eth), ETH_DECIMAL, 7, false, address(ethPriceFeed));
        vault.setToken(address(usdc), USDC_DECIMAL, 10, true, address(usdcPriceFeed));
        assertEq(vault.allAllowedTokenCount(), 3);

        vault.clearToken(address(eth));
        assertEq(vault.allAllowedTokenCount(), 2);
        assertEq(vault.allowedTokenConfig(address(eth)).decimal, 0);

        vault.clearToken(address(usdc));
        assertEq(vault.allAllowedTokenCount(), 1);
        assertEq(vault.allowedTokenConfig(address(usdc)).decimal, 0);

        vault.clearToken(address(btc));
        assertEq(vault.allAllowedTokenCount(), 0);
        assertEq(vault.allowedTokenConfig(address(btc)).decimal, 0);
    }

    function test_deposit() public {
        vault.setToken(address(btc), BTC_DECIMAL, 8, false, address(btcPriceFeed));
        vault.setToken(address(eth), ETH_DECIMAL, 7, false, address(ethPriceFeed));
        vault.setToken(address(usdc), USDC_DECIMAL, 10, true, address(usdcPriceFeed));

        btc.mint(alice, amount);
        assertEq(vault.balanceOf(alice, address(btc)), 0);

        vm.startPrank(alice);
        btc.approve(address(vault), amount);

        vault.deposit(address(btc), amount);
        assertEq(vault.balanceOf(alice, address(btc)), amount);
    }

    function test_buyingPower() public {
        uint256 ethAmount = expandDecimal(amount, ETH_DECIMAL);
        uint256 ethChainlinkPrice = ETH_PRICE * 10 ** CHAINLINK_PRICE_DECIMAL;

        eth.mint(alice, ethAmount);
        ethPriceFeed.setPrice(ethChainlinkPrice);
        vault.setToken(address(eth), ETH_DECIMAL, 7, false, address(ethPriceFeed));

        vm.startPrank(alice);
        eth.approve(address(vault), ethAmount);
        vault.deposit(address(eth), ethAmount);

        uint256 expectedBuyingPowerWithoutFactor
            = ethAmount * ethChainlinkPrice / 10 ** (ETH_DECIMAL + CHAINLINK_PRICE_DECIMAL - BUYING_POWER_DECIMAL);
        uint256 expectedBuyingPower = expectedBuyingPowerWithoutFactor * 7 / BASIS_FACTOR;
        assertEq(vault.buyingPower(alice, address(eth)), expectedBuyingPower);
    }

    function test_totalBuyingPower() public {
        uint256 btcAmount = expandDecimal(amount, BTC_DECIMAL);
        uint256 ethAmount = expandDecimal(amount, ETH_DECIMAL);
        uint256 usdcAmount = expandDecimal(amount, USDC_DECIMAL);
        uint256 btcChainlinkPrice = BTC_PRICE * 10 ** CHAINLINK_PRICE_DECIMAL;
        uint256 ethChainlinkPrice = ETH_PRICE * 10 ** CHAINLINK_PRICE_DECIMAL;
        uint256 usdcChainlinkPrice = USDC_PRICE * 10 ** CHAINLINK_PRICE_DECIMAL;

        btc.mint(alice, btcAmount);
        eth.mint(alice, ethAmount);
        usdc.mint(alice, usdcAmount);

        btcPriceFeed.setPrice(btcChainlinkPrice);
        ethPriceFeed.setPrice(ethChainlinkPrice);
        usdcPriceFeed.setPrice(usdcChainlinkPrice);

        vault.setToken(address(btc), BTC_DECIMAL, 8, false, address(btcPriceFeed));
        vault.setToken(address(eth), ETH_DECIMAL, 7, false, address(ethPriceFeed));
        vault.setToken(address(usdc), USDC_DECIMAL, 10, true, address(usdcPriceFeed));

        vm.startPrank(alice);
        btc.approve(address(vault), btcAmount);
        eth.approve(address(vault), ethAmount);
        usdc.approve(address(vault), usdcAmount);

        vault.deposit(address(btc), btcAmount);
        vault.deposit(address(eth), ethAmount);
        vault.deposit(address(usdc), usdcAmount);


        uint256 expectedTotalBuyingPower;
        expectedTotalBuyingPower +=
            btcAmount * btcChainlinkPrice / 10 ** (BTC_DECIMAL + CHAINLINK_PRICE_DECIMAL - BUYING_POWER_DECIMAL) * 8 / BASIS_FACTOR;
        expectedTotalBuyingPower +=
            ethAmount * ethChainlinkPrice / 10 ** (ETH_DECIMAL + CHAINLINK_PRICE_DECIMAL - BUYING_POWER_DECIMAL) * 7 / BASIS_FACTOR;
        expectedTotalBuyingPower +=
            usdcAmount * usdcChainlinkPrice / 10 ** (USDC_DECIMAL + CHAINLINK_PRICE_DECIMAL - BUYING_POWER_DECIMAL) * 10 / BASIS_FACTOR;

        // (7380000 * 8 / 10) + (184500 * 7 / 10) + (123 * 10 / 10)
        // = 6033273000000
        emit log_uint(expectedTotalBuyingPower);
        assertEq(vault.totalBuyingPower(alice), expectedTotalBuyingPower);
    }
}