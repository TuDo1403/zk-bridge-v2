// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Treasury {
    mapping(address => mapping(bytes32 => uint256)) public deposits;

    function notifyERC20Transfer() external {}
}
