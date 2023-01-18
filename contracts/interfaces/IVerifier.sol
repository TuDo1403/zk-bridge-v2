// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IVerifier {
    function verifyProof(
        bytes calldata proofs_,
        uint256[7] memory pubSignals_
    ) external view returns (bool);
}
