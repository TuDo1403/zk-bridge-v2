// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Vault} from "./BridgeVault.sol";

import {ReentrancyGuardUpgradeable} from "oz-custom/contracts/oz-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {Create2Deployer} from "oz-custom/contracts/internal/DeterministicDeployer.sol";
import {ProtocolFeeUpgradeable} from "oz-custom/contracts/internal-upgradeable/ProtocolFeeUpgradeable.sol";
import {FundForwarderUpgradeable} from "oz-custom/contracts/internal-upgradeable/FundForwarderUpgradeable.sol";
import {Roles, IAuthority, ManagerUpgradeable} from "oz-custom/contracts/presets-upgradeable/base/ManagerUpgradeable.sol";

import {IVerifier, IMaximaBridgeBase} from "./interfaces/IMaximaBridgeBase.sol";
import {IWithdrawableUpgradeable} from "oz-custom/contracts/internal-upgradeable/interfaces/IWithdrawableUpgradeable.sol";

import {IERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol"; //  TODO: update oz-custom
import {IERC721Upgradeable, IERC721PermitUpgradeable} from "oz-custom/contracts/oz-upgradeable/token/ERC721/extensions/IERC721PermitUpgradeable.sol";
import {IERC20Upgradeable, IERC20PermitUpgradeable} from "oz-custom/contracts/oz-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";

import {TokenType} from "./libraries/TokenType.sol";

import {SigUtil} from "oz-custom/contracts/libraries/SigUtil.sol";
import {SSTORE2} from "oz-custom/contracts/libraries/SSTORE2.sol";
import {BitMapsUpgradeable} from "oz-custom/contracts/oz-upgradeable/utils/structs/BitMapsUpgradeable.sol";
import {ERC165CheckerUpgradeable} from "oz-custom/contracts/oz-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";

/**
 * @title MaximaBridgeBase
 * @author Tu Do
 * @custom:security-contact tudo.dev@gmail.com
 * @dev The MaximaBridgeBase contract acts as a bridge between 2 chains, allowing for the transfer of tokens between them.
 * @dev The contract uses a verifier contract to check the validity of the SNARK proofs.
 * @dev The contract can be initialized by passing the verifier contract, authority contract, source token contract and target token contract.
 * @dev The operator role is required to call updateValidators, toggleRelayer, and updateVerifier.
 * @dev The contract can be used to update the validators, relay block hashes and toggle relayers.
 */
abstract contract MaximaBridgeBase is
    Create2Deployer,
    IMaximaBridgeBase,
    ManagerUpgradeable,
    ProtocolFeeUpgradeable,
    FundForwarderUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SigUtil for bytes;
    using SSTORE2 for bytes;
    using ERC165CheckerUpgradeable for address;
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

    /// @dev value is equal to keccak256("RELAYER_ROLE")
    bytes32 public constant RELAYER_ROLE =
        0xe2b7fb3b832174769106daebcfd6d1970523240dda11281102db9363b83b0dc4;

    uint256 private constant __RELAYER_ENABLED = 3;
    uint256 private constant __RELAYER_DISABLED = 2;

    IVerifier public verifier;
    address public treasury;
    address public sourceToken;
    address public targetToken;

    bytes32 internal _validators;

    uint256 private __relayersToggler;

    BitMapsUpgradeable.BitMap private __commitments;
    BitMapsUpgradeable.BitMap private __nullifierHashes;
    BitMapsUpgradeable.BitMap private __verifiedTargetBlockHashes;

    modifier whenRelayersEnabled() virtual {
        __checkRelayersEnabled();
        _;
    }

    modifier whenRelayerDisabled() virtual {
        __checkRelayerDisabled();
        _;
    }

    /**
     * @dev Initializes the contract with verifier, authority, source token and target token contracts.
     * @param verifier_ The verifier contract
     * @param authority_ The authority contract
     * @param sourceToken_ The source token contract
     * @param targetToken_ The target token contract
     */
    function __SNARKBridge_init(
        IVerifier verifier_,
        IAuthority authority_,
        address sourceToken_,
        address targetToken_
    ) internal onlyInitializing {
        _validateAddress(targetToken_);
        _validateAddress(sourceToken_);

        __ReentrancyGuard_init_unchained();
        __Manager_init_unchained(authority_, 0);
        __SNARKBridge_init_unchained(verifier_, targetToken_, sourceToken_);

        __FundForwarder_init_unchained(
            _deploy(
                address(this).balance,
                keccak256(
                    abi.encode(
                        address(this),
                        block.chainid,
                        sourceToken_,
                        targetToken_
                    )
                ),
                type(Vault).creationCode
            )
        );
    }

    function __SNARKBridge_init_unchained(
        IVerifier verifier_,
        address sourceToken_,
        address targetToken_
    ) internal onlyInitializing {
        sourceToken = sourceToken_;
        targetToken = targetToken_;

        address sender = _msgSender();

        verifier = verifier_;
        emit NewVerifier(sender, IVerifier(address(0)), verifier_);

        __relayersToggler = __RELAYER_DISABLED;
        emit ModeSwitched(sender, false);
    }

    /// @inheritdoc IMaximaBridgeBase
    function updateValidators(
        bytes calldata validators_
    ) public virtual onlyRole(Roles.OPERATOR_ROLE) {
        bytes32 pointer = validators_.write();
        emit ValidatorsUpdated(_msgSender(), pointer, validators_);
        _validators = pointer;
    }

    /// @inheritdoc IMaximaBridgeBase
    function relayBlockHashes(
        uint256[] calldata blockhashes_
    ) external onlyRole(RELAYER_ROLE) whenNotPaused whenRelayersEnabled {
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

    /// @inheritdoc IMaximaBridgeBase
    function toggleRelayer() external onlyRole(Roles.OPERATOR_ROLE) {
        __relayersToggler ^= 1;
        emit ModeSwitched(_msgSender(), isRelayersEnabled());
    }

    /// @inheritdoc IMaximaBridgeBase
    function updateVerifier(
        IVerifier verifier_
    ) external onlyRole(Roles.OPERATOR_ROLE) {
        emit NewVerifier(_msgSender(), verifier, verifier_);
        verifier = verifier_;
    }

    function deposit(
        address token_,
        uint256 value_,
        uint256 commitment_,
        Permission calldata permission_
    ) external whenNotPaused {
        address account = _msgSender();
        _checkBlacklist(account);

        if (commitment_ == 0) revert SNARKBridge__InvalidArguments();
        if (isCommited(commitment_)) revert SNARKBridge__UsedCommitment();
        if (token_ != sourceToken) revert SNARKBridge__UnsupportedToken();

        __commitments.set(commitment_);
        emit Commited(account, commitment_);

        address _vault = vault();
        __transferAsset(token_, account, _vault, value_, permission_);
        if (
            IWithdrawableUpgradeable(_vault).notifyERCTransfer(
                token_,
                abi.encode(value_),
                abi.encode(account)
            ) != IWithdrawableUpgradeable.notifyERCTransfer.selector
        ) revert SNARKBridge__NotifyFailed();

        emit Deposited(account, token_, value_, commitment_);
    }

    function withdraw(
        SnarkInputs calldata inputs_,
        bytes calldata signatures_,
        bytes calldata snarkProofs_
    ) external whenNotPaused whenRelayerDisabled {
        address account = _msgSender();
        _checkBlacklist(account);

        // TODO: validate targetBridge address
        // if (targetBridge_ != targetBridge)
        //     revert SNARKBridge__UnknownBridgeContract();
        if (inputs_.token != targetToken)
            revert SNARKBridge__UnsupportedToken();
        if (isUsedNullifierHash(inputs_.nullifierHash))
            revert SNARKBridge__AlreadyClaimed();
        if (
            !isKnownValidators(
                [
                    inputs_.preSealedBlockhashHead,
                    inputs_.preSealedBlockhashTail
                ],
                signatures_
            )
        ) revert SNARKBridge__InvalidBlockhashOrUnknownValidator();
        if (!__isValidSnarkProofs(snarkProofs_, inputs_))
            revert SNARKBrdige__InvalidSnarkProof();

        __nullifierHashes.set(inputs_.nullifierHash);
        emit NullifierHashUsed(account, inputs_.nullifierHash);

        address _sourceToken = sourceToken;

        IWithdrawableUpgradeable(vault()).withdraw(
            _sourceToken,
            inputs_.receiver,
            inputs_.value,
            ""
        );

        emit Claimed(account, _sourceToken, inputs_.value);
    }

    function isCommited(uint256 commitment_) public view returns (bool) {
        return __commitments.get(commitment_);
    }

    function isUsedNullifierHash(
        uint256 nullifierHash_
    ) public view returns (bool) {
        return __nullifierHashes.get(nullifierHash_);
    }

    /// @inheritdoc IMaximaBridgeBase
    function isRelayersEnabled() public view returns (bool) {
        return __relayersToggler == __RELAYER_ENABLED;
    }

    function isKnownValidators(
        uint256[2] memory preSealHash_,
        bytes calldata signature_
    ) public view virtual returns (bool);

    function _validateAddress(address addr_) internal pure virtual {
        if (addr_ == address(0)) revert SNARKBridge__ZeroAddress();
    }

    function __transferAsset(
        address token_,
        address from_,
        address to_,
        uint256 value_,
        Permission calldata permission_
    ) private returns (uint256) {
        if (token_.supportsInterface(type(IERC721Upgradeable).interfaceId)) {
            if (IERC721Upgradeable(token_).getApproved(value_) != address(this))
                IERC721PermitUpgradeable(token_).permit(
                    address(this),
                    value_,
                    permission_.deadline,
                    permission_.signature
                );
            IERC721Upgradeable(token_).safeTransferFrom(from_, to_, value_);
            return TokenType.ERC721;
        } else if (
            token_.supportsInterface(type(IERC1155Upgradeable).interfaceId)
        ) {
            IERC1155Upgradeable(token_).safeTransferFrom(
                from_,
                to_,
                value_,
                1,
                ""
            );
            return TokenType.ERC1155;
        } else {
            if (
                IERC20Upgradeable(token_).allowance(from_, address(this)) <
                value_
            ) {
                (bytes32 r, bytes32 s, uint8 v) = permission_
                    .signature
                    .splitSignature();
                IERC20PermitUpgradeable(token_).permit(
                    from_,
                    address(this),
                    value_,
                    permission_.deadline,
                    v,
                    r,
                    s
                );
            }

            _safeERC20TransferFrom(
                IERC20Upgradeable(token_),
                from_,
                to_,
                value_
            );
            return TokenType.ERC20;
        }
    }

    function __isValidSnarkProofs(
        bytes calldata proofs_,
        SnarkInputs calldata inputs_
    ) private view returns (bool) {
        /// @dev parse struct to statically-sized array
        uint256[7] memory pubSignals;
        assembly {
            pubSignals := inputs_
        }
        return verifier.verifyProof(proofs_, pubSignals);
    }

    function __checkRelayersEnabled() private view {
        if (!isRelayersEnabled()) revert SNARKBridge__RelayersDisabled();
    }

    function __checkRelayerDisabled() private view {
        if (isRelayersEnabled()) revert SNARKBridge__RelayersEnabled();
    }

    uint256[41] private __gap;
}
