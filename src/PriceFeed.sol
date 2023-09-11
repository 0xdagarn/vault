// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPriceFeed {
    function setPrice(uint256 _price) external;
    function getPrice() external view returns (uint256);
}

contract PriceFeed is IPriceFeed {
    // address private _gov;
    uint256 private _price;

    // modifier onlyGov() {
    //     require(msg.sender == _gov, "only gov");
    //     _;
    // }

    constructor() {
        // _gov = msg.sender;
    }

    function setPrice(uint256 price) public {
        _price = price;
    }

    function getPrice() public view returns (uint256) {
        return _price;
    }
}
