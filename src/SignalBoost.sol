// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISignalBoost} from "./interfaces/ISignalBoost.sol";

abstract contract SignalBoost is ISignalBoost {
    // Function in SignalBoost L1 contract
    function writeSignals(SignalRequest[] calldata requests) external returns (bytes32 signalRequestsRoot) {
        bytes32[] memory signals = new bytes32[](requests.length);
        bytes[] memory outputs = new bytes[](requests.length);

        for (uint256 i = 0; i < requests.length; i++) {
            // Encode the call using selector and input
            bytes memory payload = abi.encodeWithSelector(requests[i].selector, requests[i].input);

            // Call the view function
            (bool success, bytes memory output) = requests[i].target.staticcall(payload);
            if (!success) revert StaticCallReverted();

            outputs[i] = output;
        }

        // Hash the requests and outputs
        signalRequestsRoot = keccak256(abi.encode(requests, outputs));

        // Write the root to the L1 signaler contract
        _sendSignal(signalRequestsRoot);

        emit SignalSent(signalRequestsRoot);
    }

    // @dev This function is called by the writeSignals function.
    // @dev Different rollups will have different ways of importing L1 data.
    // @dev This function should be implemented by the contract to match the rollup's needs
    // @param signal the signal to send
    function _sendSignal(bytes32 signal) internal virtual {}
}
