// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IPriceFeed } from "./PriceFeed.sol";

interface IVault {
    struct Token {
        uint256 decimal;
        uint256 factor;
        bool isStable;
        address priceFeed;
    }

    event TokenSet(
        address indexed token,
        uint256 decimal,
        uint256 factor,
        bool isStable,
        address priceFeed
    );
}

contract Vault is IVault {
    IPriceFeed private _priceFeed;

    mapping(address => Token) private _allowedTokens;

    function setToken(
        address token,
        uint256 decimal,
        uint256 factor,
        bool isStable,
        address priceFeed
    ) public {
        _allowedTokens[token] = Token(decimal, factor, isStable, priceFeed);
        emit TokenSet(token, decimal, factor, isStable, priceFeed);
    }

    function allowedToken(address token) public view returns (Token memory) {
        return _allowedTokens[token];
    }
}
