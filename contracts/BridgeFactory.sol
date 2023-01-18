// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "oz-custom/contracts/libraries/Create3.sol";
import "oz-custom/contracts/oz/proxy/beacon/BeaconProxy.sol";

contract BridgeFactory {
    function deployBridge(
        address sourceToken_,
        address targetToken_,
        uint256 chainIdTarget_
    ) external {
        bytes32 salt = keccak256(
            abi.encode(
                block.chainid,
                chainIdTarget_,
                sourceToken_,
                targetToken_,
                address(this)
            )
        );
    }
}
