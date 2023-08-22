//SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "../interface/IProxy.sol";
import "../interface/IBridge.sol";
import "../interface/IGovernance.sol";
import "../interface/ICommon.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Governance is IGovernance, ReentrancyGuard {
    uint256 private constant MAX_UINT = 2 ** 256 - 1;

    uint8 private immutable version;
    uint256 private immutable thresholdVotingPower;

    bytes32 public currentValidatorSetHash;
    bytes32 public nextValidatorSetHash;
    uint256 public validatorSetNonce = 0;

    IProxy private proxy;

    constructor(
        uint8 _version,
        address[] memory _currentValidators,
        uint256[] memory _currentPowers,
        address[] memory _nextValidators,
        uint256[] memory _nextPowers,
        uint256 _thresholdVotingPower,
        IProxy _proxy
    ) {
        require(_currentValidators.length == _currentPowers.length, "Mismatch array length.");
        require(_nextValidators.length == _nextPowers.length, "Mismatch array length.");
        require(_isEnoughVotingPower(_currentPowers, _thresholdVotingPower), "Invalid voting power threshold.");
        require(_isEnoughVotingPower(_nextPowers, _thresholdVotingPower), "Invalid voting power threshold.");

        version = _version;
        thresholdVotingPower = _thresholdVotingPower;
        currentValidatorSetHash = _computeValidatorSetHash(_currentValidators, _currentPowers, MAX_UINT);
        nextValidatorSetHash = _computeValidatorSetHash(_nextValidators, _nextPowers, 0);

        proxy = IProxy(_proxy);
    }

    function upgradeContract(
        ValidatorSetArgs calldata _validators,
        Signature[] calldata _signatures,
        string calldata _name,
        address _address
    ) external {
        require(_address != address(0), "Invalid address.");
        require(keccak256(abi.encode(_name)) != keccak256(abi.encode("bridge")), "Invalid contract name.");

        bytes32 messageHash = keccak256(abi.encode(version, "upgradeContract", _name, _address));

        require(authorize(_validators, _signatures, messageHash), "Unauthorized.");

        proxy.upgradeContract(_name, _address);
    }

    function upgradeBridgeContract(
        ValidatorSetArgs calldata _validators,
        Signature[] calldata _signatures,
        address _address
    ) external {
        require(_address != address(0), "Invalid address.");
        bytes32 messageHash = keccak256(abi.encode(version, "upgradeBridgeContract", "bridge", _address));
        address bridgeAddress = proxy.getContract("bridge");
        IBridge bridge = IBridge(bridgeAddress);

        require(bridge.authorize(_validators, _signatures, messageHash), "Unauthorized.");

        proxy.upgradeContract("bridge", _address);
    }

    function addContract(
        ValidatorSetArgs calldata _validators,
        Signature[] calldata _signatures,
        string calldata _name,
        address _address
    ) external nonReentrant {
        require(_address != address(0), "Invalid address.");
        bytes32 messageHash = keccak256(abi.encode(version, "addContract", _name, _address));

        require(authorize(_validators, _signatures, messageHash), "Unauthorized.");

        proxy.addContract(_name, _address);
    }

    function updateValidatorsSet(
        ValidatorSetArgs calldata _currentValidatorSetArgs,
        bytes32 _bridgeValidatorSetHash,
        bytes32 _governanceValidatorSetHash,
        Signature[] calldata _signatures,
        uint256 nonce
    ) external {
        require(
            _currentValidatorSetArgs.validators.length == _currentValidatorSetArgs.powers.length &&
                _currentValidatorSetArgs.validators.length == _signatures.length,
            "Malformed input."
        );
        require(validatorSetNonce + 1 == nonce, "Invalid nonce.");

        address bridgeAddress = proxy.getContract("bridge");
        IBridge bridge = IBridge(bridgeAddress);

        bytes32 messageHash = keccak256(
            abi.encode(version, "updateValidatorsSet", _bridgeValidatorSetHash, _governanceValidatorSetHash, nonce)
        );

        validatorSetNonce = nonce;

        require(bridge.authorizeNext(_currentValidatorSetArgs, _signatures, messageHash), "Unauthorized.");

        currentValidatorSetHash = nextValidatorSetHash;
        nextValidatorSetHash = _governanceValidatorSetHash;
        bridge.updateValidatorSetHash(_bridgeValidatorSetHash);

        emit ValidatorSetUpdate(validatorSetNonce, _governanceValidatorSetHash, _bridgeValidatorSetHash);
    }

    function authorize(
        ValidatorSetArgs calldata _validators,
        Signature[] calldata _signatures,
        bytes32 _messageHash
    ) private view returns (bool) {
        require(_validators.validators.length == _validators.powers.length, "Malformed input.");
        require(_computeValidatorSetHash(_validators) == currentValidatorSetHash, "Invalid currentValidatorSetHash.");

        uint256 powerAccumulator = 0;
        for (uint256 i = 0; i < _validators.powers.length; i++) {
            if (!isValidSignature(_validators.validators[i], _messageHash, _signatures[i])) {
                continue;
            }

            powerAccumulator = powerAccumulator + _validators.powers[i];
            if (powerAccumulator >= thresholdVotingPower) {
                return true;
            }
        }
        return powerAccumulator >= thresholdVotingPower;
    }

    function isValidSignature(
        address _signer,
        bytes32 _messageHash,
        Signature calldata _signature
    ) internal pure returns (bool) {
        bytes32 messageDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
        (address signer, ECDSA.RecoverError error) = ECDSA.tryRecover(
            messageDigest,
            _signature.v,
            _signature.r,
            _signature.s
        );
        return error == ECDSA.RecoverError.NoError && _signer == signer;
    }

    function _computeValidatorSetHash(ValidatorSetArgs calldata validatorSetArgs) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    version,
                    "governance",
                    validatorSetArgs.validators,
                    validatorSetArgs.powers,
                    validatorSetArgs.nonce
                )
            );
    }

    function _computeValidatorSetHash(
        address[] memory validators,
        uint256[] memory powers,
        uint256 nonce
    ) internal view returns (bytes32) {
        return keccak256(abi.encode(version, "governance", validators, powers, nonce));
    }

    function _isEnoughVotingPower(
        uint256[] memory _powers,
        uint256 _thresholdVotingPower
    ) internal pure returns (bool) {
        uint256 powerAccumulator = 0;

        for (uint256 i = 0; i < _powers.length; i++) {
            powerAccumulator = powerAccumulator + _powers[i];
            if (powerAccumulator >= _thresholdVotingPower) {
                return true;
            }
        }
        return false;
    }
}
