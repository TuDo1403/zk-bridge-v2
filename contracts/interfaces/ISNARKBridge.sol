// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IVerifier.sol";

interface ISNARKBridge {
    error SNARKBridge__ZeroAddress();
    error SNARKBridge__NotifyFailed();
    error SNARKBridge__UsedCommitment();
    error SNARKBridge__AlreadyClaimed();
    error SNARKBridge__RelayersEnabled();
    error SNARKBridge__UnsupportedToken();
    error SNARKBridge__InvalidArguments();
    error SNARKBridge__RelayersDisabled();
    error SNARKBrdige__InvalidSnarkProof();
    error SNARKBridge__UnknownBridgeContract();
    error SNARKBridge__InvalidBlockhashOrUnknownValidator();

    struct Permission {
        uint256 deadline;
        bytes signature;
    }

    struct SnarkInputs {
        address token;
        uint256 value;
        address receiver;
        address targetBridge;
        uint256 nullifierHash;
        uint256 preSealedBlockhashHead;
        uint256 preSealedBlockhashTail;
    }

    event ValidatorsUpdated(
        address indexed operator,
        bytes32 indexed pointer,
        bytes validators
    );

    event Commited(address indexed account, uint256 indexed commitment);

    event NullifierHashUsed(
        address indexed account,
        uint256 indexed nullifierHash
    );

    event NewVerifier(
        address indexed operator,
        IVerifier indexed from,
        IVerifier indexed to
    );

    event Deposited(
        address indexed account,
        address indexed sourceToken,
        uint256 indexed value,
        uint256 commitment
    );

    event Claimed(
        address indexed account,
        address indexed targetToken,
        uint256 indexed value
    );

    event ModeSwitched(address indexed operator, bool indexed relayerEnabled);
    event BlockHashesRelayed(address indexed relayer, uint256[] blockhashes);

    function updateValidators(bytes calldata validators_) external;

    function relayBlockHashes(uint256[] calldata blockhashes_) external;

    function toggleRelayer() external;

    function updateVerifier(IVerifier verifier_) external;

    function deposit(
        address token_,
        uint256 value_,
        uint256 commitment_,
        Permission calldata permission_
    ) external;

    function withdraw(
        SnarkInputs calldata inputs_,
        bytes calldata signatures_,
        bytes calldata snarkProofs_
    ) external;

    function isCommited(uint256 commitment_) external view returns (bool);

    function isUsedNullifierHash(
        uint256 nullifierHash_
    ) external view returns (bool);

    function isRelayersEnabled() external view returns (bool);

    function isKnownValidators(
        uint256[2] memory preSealHash_,
        bytes calldata signature_
    ) external view returns (bool);
}
