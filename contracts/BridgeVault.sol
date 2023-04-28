// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "oz-custom/contracts/oz/access/Ownable.sol";
import "oz-custom/contracts/internal/Withdrawable.sol";
import "oz-custom/contracts/oz/utils/introspection/ERC165Checker.sol";

import "oz-custom/contracts/oz/token/ERC20/IERC20.sol";
import "oz-custom/contracts/oz/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol"; //  TODO: update oz-custom

contract Vault is Ownable, Withdrawable {
    using ERC165Checker for address;

    /// @dev value is equal to keccak256("Vault_v1")
    bytes32 public constant VERSION =
        0x04d7bd3a27c72166a84b551c16c2e397b54ccc7826e6d895e825544827f5c7f8;

    constructor() payable Ownable() {}

    function notifyERCTransfer(
        address token_,
        bytes calldata value_,
        bytes calldata data_
    ) external override onlyOwner returns (bytes4) {
        emit Received(abi.decode(data_, (address)), token_, value_, data_);
        return IWithdrawable.notifyERCTransfer.selector;
    }

    function withdraw(
        address token_,
        address to_,
        uint256 value_,
        bytes calldata
    ) external override onlyOwner {
        if (token_.supportsInterface(type(IERC721).interfaceId))
            IERC721(token_).safeTransferFrom(address(this), to_, value_);
        else if (token_.supportsInterface(type(IERC1155).interfaceId))
            IERC1155(token_).safeTransferFrom(
                address(this),
                to_,
                value_,
                1,
                ""
            );
        else _safeERC20Transfer(IERC20(token_), to_, value_);

        emit Withdrawn(token_, to_, value_);
    }
}
