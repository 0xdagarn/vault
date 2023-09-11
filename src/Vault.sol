// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IPriceFeed } from "./PriceFeed.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "forge-std/console.sol";

interface IVault {
    struct TokenConfig {
        uint256 decimal;
        uint256 factor;
        bool isStable;
        address priceFeed;
    }

    event TokenConfigSet(
        address indexed token,
        uint256 decimal,
        uint256 factor,
        bool isStable,
        address priceFeed
    );
    event TokenConfigCleared(address indexed token);
    event Deposited(address indexed account, address indexed token, uint256 amount);
}

contract Vault is IVault {
    uint256 constant public BASIS_FACTOR = 10;
    uint256 constant public BUYING_POWER_DECIMAL = 6;
    uint256 constant public CHAINLINK_PRICE_DECIMAL = 8;

    address[] private _allAllowedTokens;
    mapping(address => TokenConfig) private _allowedTokenConfigs;
    mapping(address => mapping(address => uint256)) _balances;

    function setToken(
        address token,
        uint256 decimal,
        uint256 factor,
        bool isStable,
        address priceFeed
    ) public {
        require(
            _allowedTokenConfigs[token].decimal == 0,
            "Vault: token already set"
        );
        _allAllowedTokens.push(token);

        _allowedTokenConfigs[token] = TokenConfig(decimal, factor, isStable, priceFeed);
        emit TokenConfigSet(token, decimal, factor, isStable, priceFeed);
    }

    function clearToken(address token) public returns (bool) {
        require(
            _allowedTokenConfigs[token].decimal > 0,
            "Vault: token alread cleared"
        );

        bool found; // false

        uint256 index;
        for (uint256 i = 0; i < _allAllowedTokens.length; i++) {
            if (_allAllowedTokens[i] == token) {
                index = i;
                found = true;
                break;
            }
        }

        if (found) {
            _allAllowedTokens[index] = _allAllowedTokens[_allAllowedTokens.length - 1];
            _allAllowedTokens.pop();

            delete _allowedTokenConfigs[token];
            emit TokenConfigCleared(token);
        }

        return found;
    }

    function deposit(address _token, uint256 _amount) external {
        require(
            _allowedTokenConfigs[_token].decimal > 0,
            "Vault: token not allowed"
        );

        IERC20(_token).transferFrom(msg.sender, address(this), _amount );

        _balances[msg.sender][_token] += _amount;
        emit Deposited(msg.sender, _token, _amount);
    }

    function buyingPower(address account, address token) public view returns (uint256) {
        TokenConfig memory tokenConfig = _allowedTokenConfigs[token];
        require(tokenConfig.decimal > 0, "Vault: token not allowed");

        uint256 balance = _balances[account][token];
        uint256 price = IPriceFeed(tokenConfig.priceFeed).getPrice();
        uint256 buyingPowerWithoutFactor =
            balance * price / 10 ** (tokenConfig.decimal + CHAINLINK_PRICE_DECIMAL - BUYING_POWER_DECIMAL);

        if (tokenConfig.factor == 0) {
            return buyingPowerWithoutFactor;
        }

        return buyingPowerWithoutFactor * tokenConfig.factor / BASIS_FACTOR;
    }

    function totalBuyingPower(address account) public view returns (uint256 buyingPower_) {
        for (uint256 i = 0; i < _allAllowedTokens.length; i++) {
            address token = _allAllowedTokens[i];
            buyingPower_ += buyingPower(account, token);
        }
    }

    function allowedTokenConfig(address token) public view returns (TokenConfig memory) {
        return _allowedTokenConfigs[token];
    }

    function allAllowedTokenCount() public view returns (uint256) {
        return _allAllowedTokens.length;
    }

    function balanceOf(address account, address token) public view returns (uint256) {
        return _balances[account][token];
    }
}
