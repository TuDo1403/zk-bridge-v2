// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {SSTORE2, SNARKBridge, IVerifier, IAuthorityUpgradeable} from "./SNARKBridge.sol";

import "./interfaces/IBLSBridge.sol";

import "./libraries/BLS.sol";

contract BLSBridge is IBLSBridge, SNARKBridge {
    using SSTORE2 for bytes32;

    /// @dev value is equal to keccak256("BLSBridge_v1")
    bytes32 public constant VERSION =
        0x0e7178bff043a47dfb078f107cf2defcf9f7ef4838f8141f562e75780aec8865;

    function initialize(
        IVerifier verifier_,
        IAuthorityUpgradeable authority_,
        address sourceToken_,
        address targetToken_
    ) external initializer {
        __SNARKBridge_init(verifier_, authority_, sourceToken_, targetToken_);
    }

    function validators() public view returns (uint256[4][] memory) {
        return abi.decode(_validators.read(), (uint256[4][]));
    }

    function isKnownValidators(
        uint256[2] memory preSealedBlockHash_,
        bytes calldata signature_
    ) public view override(ISNARKBridge, SNARKBridge) returns (bool) {
        uint256[2] memory signature = abi.decode(signature_, (uint256[2]));
        uint256[4][] memory pubKeys = validators();
        uint256 length = pubKeys.length;
        for (uint256 i; i < length; ) {
            if (BLS.verifySingle(signature, pubKeys[i], preSealedBlockHash_))
                return true;
            unchecked {
                ++i;
            }
        }
        return false;
    }

    uint256[50] private __gap;
}
