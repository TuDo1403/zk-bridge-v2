// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./internal-upgradeable/BaseUpgradeable.sol";

import "oz-custom/contracts/internal-upgradeable/ProtocolFeeUpgradeable.sol";
import "oz-custom/contracts/internal-upgradeable/ProxyCheckerUpgradeable.sol";
import "oz-custom/contracts/internal-upgradeable/FundForwarderUpgradeable.sol";

import "./interfaces/ISNARKBridge.sol";

import "oz-custom/contracts/oz-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "oz-custom/contracts/oz-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol"; //  TODO: update oz-custom

import "oz-custom/contracts/libraries/SSTORE2.sol";
import "oz-custom/contracts/oz-upgradeable/utils/structs/BitMapsUpgradeable.sol";
import "oz-custom/contracts/oz-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";

abstract contract SNARKBridge is
    ISNARKBridge,
    BaseUpgradeable,
    ProxyCheckerUpgradeable,
    FundForwarderUpgradeable
{
    using SSTORE2 for bytes;
    using ERC165CheckerUpgradeable for address;
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

    uint256 private constant __RELAYER_ENABLED = 3;
    uint256 private constant __RELAYER_DISABLED = 2;

    IVerifier public verifier;
    address public sourceToken;
    address public targetToken;

    bytes32 internal _validators;

    uint256 private __relayersToggler;
    BitMapsUpgradeable.BitMap private __commitments;
    BitMapsUpgradeable.BitMap private __nullifierHashes;
    BitMapsUpgradeable.BitMap private __verifiedTargetBlockHashes;

    modifier nonZeroAddress(address addr_) {
        __checkZeroAddress(addr_);
        _;
    }

    modifier whenRelayersEnabled() {
        __checkRelayersEnabled();
        _;
    }

    modifier whenRelayerDisabled() {
        __checkRelayerDisabled();
        _;
    }

    function __SNARKBridgeBase_init(
        ITreasury vault_,
        IVerifier verifier_,
        IAuthority authority_,
        address sourceToken_,
        address targetToken_
    ) internal onlyInitializing {
        if (!_isProxy(sourceToken_)) revert SNARKBridge__InvalidArguments();

        __checkZeroAddress(sourceToken_);
        __checkZeroAddress(targetToken_);

        address _vault = address(vault_);

        __FundForwarder_init_unchained(_vault);
        __Base_init_unchained(authority_, Roles.TREASURER_ROLE);
        __SNARKBridgeBase_init_unchained(verifier_, targetToken_, sourceToken_);
    }

    function __SNARKBridgeBase_init_unchained(
        IVerifier verifier_,
        address sourceToken_,
        address targetToken_
    ) internal onlyInitializing {
        sourceToken = sourceToken_;
        targetToken = targetToken_;

        verifier = verifier_;
        emit NewVerifier(_msgSender(), IVerifier(address(0)), verifier_);

        __relayersToggler = __RELAYER_DISABLED;
        emit ModeSwitched(_msgSender(), false);
    }

    function updateValidators(
        bytes calldata validators_
    ) public virtual onlyRole(Roles.OPERATOR_ROLE) {
        bytes32 pointer = validators_.write();

        emit ValidatorsUpdated(_msgSender(), pointer, validators_);
        _validators = pointer;
    }

    function relayBlockHashes(
        uint256[] calldata blockhashes_
    ) external onlyRole(Roles.RELAYER_ROLE) whenNotPaused whenRelayersEnabled {
        uint256 length = blockhashes_.length;
        for (uint256 i; i < length; ) {
            if (blockhashes_[i] == 0) revert SNARKBridge__InvalidArguments();
            __verifiedTargetBlockHashes.set(blockhashes_[i]);
            unchecked {
                ++i;
            }
        }

        emit BlockHashesRelayed(_msgSender(), blockhashes_);
    }

    function toggleRelayer() external onlyRole(Roles.OPERATOR_ROLE) {
        __relayersToggler ^= 1;

        emit ModeSwitched(_msgSender(), isRelayersEnabled());
    }

    function updateVerifier(
        IVerifier verifier_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        emit NewVerifier(_msgSender(), verifier, verifier_);
        verifier = verifier_;
    }

    function updateTreasury(ITreasury treasury_) external virtual override {}

    function deposit(
        address token_,
        uint256 value_,
        uint256 commitment_,
        Permission calldata permission_
    ) external whenNotPaused {
        address account = _msgSender();
        _checkBlacklist(account);
        _onlyEOA(account);

        if (commitment_ == 0) revert SNARKBridge__InvalidArguments();
        if (isCommited(commitment_)) revert SNARKBridge__UsedCommitment();
        if (token_ != sourceToken) revert SNARKBridge__UnsupportedToken();

        __commitments.set(commitment_);
        emit Commited(account, commitment_);

        __transferAsset(token_, account, vault, value_);

        emit Deposited(account, token_, value_, commitment_);
    }

    function withdraw(
        address token_,
        address targetBridge_,
        uint256 value_,
        address receiver_,
        uint256 nullifierHash_,
        uint256[2] calldata preSealHash_,
        bytes calldata signatures_
    ) external whenNotPaused {
        address account = _msgSender();
        _checkBlacklist(account);
        _onlyEOA(account);

        // if (targetBridge_ != targetBridge)
        //     revert SNARKBridge__UnknownBridgeContract();
        if (isUsedNullifierHash(nullifierHash_))
            revert SNARKBridge__AlreadyClaimed();
        if (token_ != targetToken) revert SNARKBridge__UnsupportedToken();

        if (!isKnownValidators(preSealHash_, signatures_))
            revert SNARKBridge__InvalidBlockhashOrUnknownValidator();

        __nullifierHashes.set(nullifierHash_);
        emit NullifierHashUsed(account, nullifierHash_);

        address _sourceToken = sourceToken;
        __transferAsset(_sourceToken, vault, receiver_, value_);
        emit Claimed(account, _sourceToken, value_);
    }

    function isCommited(uint256 commitment_) public view returns (bool) {
        return __commitments.get(commitment_);
    }

    function isUsedNullifierHash(
        uint256 nullifierHash_
    ) public view returns (bool) {
        return __nullifierHashes.get(nullifierHash_);
    }

    function isRelayersEnabled() public view returns (bool) {
        return __relayersToggler == __RELAYER_ENABLED;
    }

    function isKnownValidators(
        uint256[2] calldata preSealHash_,
        bytes calldata signature_
    ) public view virtual returns (bool);

    function __transferAsset(
        address token_,
        address from_,
        address to_,
        uint256 value_
    ) private {
        if (token_.supportsInterface(type(IERC721Upgradeable).interfaceId))
            IERC721Upgradeable(token_).safeTransferFrom(from_, to_, value_);
        else if (
            token_.supportsInterface(type(IERC1155Upgradeable).interfaceId)
        )
            IERC1155Upgradeable(token_).safeTransferFrom(
                from_,
                to_,
                value_,
                1,
                ""
            );
        else
            _safeERC20TransferFrom(
                IERC20Upgradeable(token_),
                from_,
                to_,
                value_
            );

        // IWithdrawable(_vault).notifyERCTransfer(
        //     token_,
        //     abi.encode(value_),
        //     abi.encode(from_)
        // );
    }

    function __checkRelayersEnabled() private view {
        if (!isRelayersEnabled()) revert SNARKBridge__RelayersDisabled();
    }

    function __checkRelayerDisabled() private view {
        if (isRelayersEnabled()) revert SNARKBridge__RelayersEnabled();
    }

    function __checkZeroAddress(address addr_) private pure {
        if (addr_ == address(0)) revert SNARKBridge__ZeroAddress();
    }

    uint256[41] private __gap;
}
