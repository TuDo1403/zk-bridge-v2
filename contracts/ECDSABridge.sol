// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Roles, SSTORE2, SNARKBridge, BitMapsUpgradeable} from "./SNARKBridge.sol";

import "./interfaces/IECDSABridge.sol";

import "oz-custom/contracts/oz-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

contract ECDSABridge is IECDSABridge, SNARKBridge {
    using SSTORE2 for *;
    using ECDSAUpgradeable for bytes32;
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

    uint256 private __nonce;
    mapping(uint256 => BitMapsUpgradeable.BitMap) private __knownValidators;

    function updateValidators(
        bytes calldata validators_
    ) public override(ISNARKBridge, SNARKBridge) onlyRole(Roles.OPERATOR_ROLE) {
        super.updateValidators(validators_);

        //  @dev prevent unused validators
        BitMapsUpgradeable.BitMap storage knownValidators;
        unchecked {
            knownValidators = __knownValidators[__nonce++];
        }

        address[] memory ori = __decodeValidators(validators_);
        uint256[] memory parsed;
        assembly {
            parsed := ori
        }

        uint256 length = parsed.length;
        for (uint256 i; i < length; ) {
            knownValidators.set(parsed[i]);
            unchecked {
                ++i;
            }
        }
    }

    function validators() public view returns (address[] memory validators_) {
        return __decodeValidators(_validators.read());
    }

    function isKnownValidators(
        uint256[2] calldata preSealHash_,
        bytes calldata signature_
    ) public view override(ISNARKBridge, SNARKBridge) returns (bool) {
        uint256 preSealHash = (preSealHash_[0] << 128) | preSealHash_[1];

        address signer = bytes32(preSealHash).recover(signature_);
        uint256 parsedSigner;
        assembly {
            parsedSigner := signer
        }
        unchecked {
            return __knownValidators[__nonce - 1].get(parsedSigner);
        }
    }

    function __decodeValidators(
        bytes memory validators_
    ) private pure returns (address[] memory _validators) {
        return abi.decode(validators_, (address[]));
    }

    uint256[48] private __gap;
}
