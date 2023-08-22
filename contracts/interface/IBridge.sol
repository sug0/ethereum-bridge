//SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "./ICommon.sol";

interface IBridge is ICommon {
    event TransferToNamada(uint256 nonce, NamadaTransfer[] transfers, bool[] validMap, uint256 confirmations);

    event TransferToErc(uint256 indexed nonce, Erc20Transfer[] transfers, bool[] validMap, string relayerAddress);

    function authorize(
        ValidatorSetArgs calldata validatorSetArgs,
        Signature[] calldata signatures,
        bytes32 message
    ) external view returns (bool);

    function authorizeNext(
        ValidatorSetArgs calldata validatorSetArgs,
        Signature[] calldata signatures,
        bytes32 message
    ) external view returns (bool);

    function transferToNamada(NamadaTransfer[] calldata transfers, uint256 confirmations) external;

    function transferToErc(RelayProof calldata relayProof) external;

    function updateValidatorSetHash(bytes32 _validatorSetHash) external;
}
