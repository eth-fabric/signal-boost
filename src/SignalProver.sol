// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISignalBoost} from "./interfaces/ISignalBoost.sol";
import {ISignalProver} from "./interfaces/ISignalProver.sol";
import {ISignalReceiver} from "./interfaces/ISignalReceiver.sol";
import {MerkleTree} from "./lib/MerkleTree.sol";

// Contract that verifies signals against the stored root
contract SignalProver is ISignalProver {
    // Mapping from request hash to output
    mapping(bytes32 requestHash => bytes output) public requestOutputs;

    // The L2 contract that receives the signals
    ISignalReceiver public signalReceiver;

    constructor(address signalReceiver_) {
        signalReceiver = ISignalReceiver(signalReceiver_);
    }

    function proveSignals(ISignalBoost.SignalRequest[] calldata requests, bytes[] calldata outputs) external {
        if (requests.length != outputs.length) revert InputLengthMismatch();

        // Generate signal hashes
        bytes32[] memory signals = new bytes32[](requests.length);
        for (uint256 i = 0; i < requests.length; i++) {
            signals[i] = keccak256(abi.encode(requests[i], outputs[i]));
        }

        // Generate Merkle root
        bytes32 root = MerkleTree.generateTree(signals);

        // Verify against stored root
        if (!ISignalReceiver(signalReceiver).signalReceived(root)) revert SignalDoesNotExist();

        // Store each request's output
        for (uint256 i = 0; i < requests.length; i++) {
            bytes32 requestHash = keccak256(abi.encode(requests[i]));
            requestOutputs[requestHash] = outputs[i];
        }
    }

    function getOutput(bytes32 requestHash) external view returns (bytes memory) {
        return requestOutputs[requestHash];
    }

    function getOutput(ISignalBoost.SignalRequest calldata request) external view returns (bytes memory) {
        return requestOutputs[keccak256(abi.encode(request))];
    }
}
