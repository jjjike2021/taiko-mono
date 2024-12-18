// SPDX-License-Identifier: MIT

// Referenced from: https://ethresear.ch/t/slashing-proofoor-on-chain-slashed-validator-proofs/19421
pragma solidity ^0.8.24;

import "./LibMerkleUtils.sol";

/// @title LibEIP4788
/// @custom:security-contact security@taiko.xyz
library LibEIP4788 {
    struct InclusionProof {
        // `Chunks` of the SSZ encoded validator
        bytes32[8] validator;
        // Index of the validator in the beacon state validator list
        uint256 validatorIndex;
        // Proof of inclusion of validator in beacon state validator list
        bytes32[] validatorProof;
        // Root of the validator list in the beacon state
        bytes32 validatorsRoot;
        // Proof of inclusion of validator list in the beacon state
        bytes32[] beaconStateProof;
        // Root of the beacon state
        bytes32 beaconStateRoot;
        // Proof of inclusion of beacon state in the beacon block
        bytes32[] beaconBlockProofForState;
        // Proof of inclusion of the validator index in the beacon block
        bytes32[] beaconBlockProofForProposerIndex;
    }

    /// @dev The validator pub key failed verification against the pub key hash tree root in the
    /// validator chunks
    error InvalidValidatorBLSPubKey();
    /// @dev The proof that the validator is a part of the validator list is invalid.
    error ValidatorProofFailed();
    /// @dev The proof that the validator list is a part of the beacon state is invalid.
    error BeaconStateProofFailed();
    /// @dev The proof that the beacon state is a part of the beacon block is invalid.
    error BeaconBlockProofForStateFailed();
    /// @dev The proof that the actual validator index is a part of the beacon is invalid.
    error BeaconBlockProofForProposerIndex();

    function verifyValidator(
        bytes memory validatorBLSPubKey,
        bytes32 beaconBlockRoot,
        InclusionProof memory inclusionProof
    )
        internal
        pure
    {
        // Validator's BLS public key is verified against the hash tree root within Validator chunks
        bytes32 pubKeyHashTreeRoot = sha256(abi.encodePacked(validatorBLSPubKey, bytes16(0)));
        require(pubKeyHashTreeRoot == inclusionProof.validator[0], InvalidValidatorBLSPubKey());

        // Validator is verified against the validator list in the beacon state
        bytes32 validatorHashTreeRoot = LibMerkleUtils.merkleize(inclusionProof.validator);
        require(
            LibMerkleUtils.verifyProof(
                inclusionProof.validatorProof,
                inclusionProof.validatorsRoot,
                validatorHashTreeRoot,
                inclusionProof.validatorIndex
            ),
            ValidatorProofFailed()
        );

        require(
            LibMerkleUtils.verifyProof(
                inclusionProof.beaconStateProof,
                inclusionProof.beaconStateRoot,
                inclusionProof.validatorsRoot,
                11
            ),
            BeaconStateProofFailed()
        );

        // Beacon state is verified against the beacon block
        require(
            LibMerkleUtils.verifyProof(
                inclusionProof.beaconBlockProofForState,
                beaconBlockRoot,
                inclusionProof.beaconStateRoot,
                3
            ),
            BeaconBlockProofForStateFailed()
        );

        // Validator index is verified against the beacon block
        require(
            LibMerkleUtils.verifyProof(
                inclusionProof.beaconBlockProofForProposerIndex,
                beaconBlockRoot,
                LibMerkleUtils.toLittleEndian(inclusionProof.validatorIndex),
                1
            ),
            BeaconBlockProofForProposerIndex()
        );
    }
}
