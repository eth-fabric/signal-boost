// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISignalBoost {
    /// @notice A request to call a view function on an L1 contract.
    struct SignalRequest {
        /// @notice L1 contract to query
        address target;
        /// @notice Function selector of the view function
        bytes4 selector;
        /// @notice Arbitrary function inputs
        bytes input;
    }

    function writeSignals(SignalRequest[] calldata requests) external returns (bytes32 signalRequestsRoot);
    function setSignalReceiver(address signalReceiver_) external;
    function signalReceiver() external view returns (address);

    event SignalHashed(bytes32 signal, SignalRequest request, bytes output);
    event SignalSent(bytes32 signalRequestsRoot);

    // errors
    error NotOwner();
    error StaticCallReverted();
}
