//SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface ICommon {
    struct ValidatorSetArgs {
        address[] validators;
        uint256[] powers;
        uint256 nonce;
    }

    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    struct NamadaTransfer {
        address from;
        uint256 amount;
        string to;
    }

    struct Erc20Transfer {
        address from;
        address to;
        uint256 amount;
        bytes32 namadaDataDigest;
    }

    struct RelayProof {
        ValidatorSetArgs validatorSetArgs;
        Signature[] signatures;
        Erc20Transfer[] transfers;
        bytes32 poolRoot;
        bytes32[] proof;
        bool[] proofFlags;
        uint256 batchNonce;
        string relayerAddress;
    }
}
