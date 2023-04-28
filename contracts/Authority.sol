//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Create2Deployer} from "oz-custom/contracts/internal/DeterministicDeployer.sol";

import {Treasury} from "oz-custom/contracts/presets-upgradeable/Treasury.sol";
import {Roles, AuthorityUpgradeable} from "oz-custom/contracts/presets-upgradeable/AuthorityUpgradeable.sol";

contract MaximaAuthority is Create2Deployer, AuthorityUpgradeable {
    function initialize(
        address admin_,
        bytes calldata data_,
        bytes32[] calldata roles_,
        address[] calldata operators_
    ) external initializer {
        __MaximaAuthority_init_unchained();
        __Authority_init(admin_, data_, operators_, roles_);
    }

    function __MaximaAuthority_init_unchained() internal onlyInitializing {
        _setRoleAdmin(Roles.MINTER_ROLE, Roles.OPERATOR_ROLE);
    }

    function _deployDefaultTreasury(
        address admin_,
        bytes memory
    ) internal override returns (address) {
        return
            _deploy(
                address(this).balance,
                keccak256(abi.encode(admin_, address(this), VERSION)),
                abi.encodePacked(
                    type(Treasury).creationCode,
                    abi.encode(address(this), "MAXIMA_MAIN_VAULT")
                )
            );
    }

    function safeRecoverHeader() public pure override returns (bytes memory) {
        /// @dev value is equal keccak256("SAFE_RECOVER_HEADER")
        return
            bytes.concat(
                bytes32(
                    0x556d79614195ebefcc31ab1ee514b9953934b87d25857902370689cbd29b49de
                )
            );
    }

    function safeTransferHeader() public pure override returns (bytes memory) {
        /// @dev value is equal keccak256("SAFE_TRANSFER")
        return
            bytes.concat(
                bytes32(
                    0xc9627ddb76e5ee80829319617b557cc79498bbbc5553d8c632749a7511825f5d
                )
            );
    }

    uint256[50] private __gap;
}
