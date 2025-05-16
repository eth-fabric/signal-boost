// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISignalBoost} from "./ISignalBoost.sol";
import {MerkleTree} from "./lib/MerkleTree.sol";

abstract contract SignalBoost is ISignalBoost {
    address private _l1Signaler;
    address private _owner;

    constructor(address l1Signaler_, address owner_) {
        _l1Signaler = l1Signaler_;
        _owner = owner_;
    }

    // Function in SignalBoost L1 contract
    function writeSignals(SignalRequest[] memory requests) external returns (bytes32 signalRequestsRoot) {
        bytes32[] memory signals = new bytes32[](requests.length);

        for (uint256 i = 0; i < requests.length; i++) {
            // Encode the call using selector and input
            bytes memory payload = abi.encodeWithSelector(
                requests[i].selector,
                requests[i].input
            );

            // Call the view function
            (bool success, bytes memory output) = requests[i].target.staticcall(
                payload
            );
            if (!success) revert StaticCallReverted();

            // Create Merkle leaf
            signals[i] = _hashSignal(requests[i], output);

            emit SignalHashed(signals[i], requests[i], output);
        }

        // Merklize the signals
        signalRequestsRoot = MerkleTree.generateTree(signals);

        // Write the root to the L1 signaler contract
        _sendSignal(signalRequestsRoot);

        emit SignalSent(signalRequestsRoot);
    }

    function setL1Signaler(address signaler_) external {
        if (msg.sender != _owner) revert NotOwner();
        _l1Signaler = signaler_;
    }

    // internal functions
    function _hashSignal(
        SignalRequest calldata request,
        bytes memory output
    ) internal pure returns (bytes32) {
        bytes32 signal = keccak256(abi.encode(request, output));
        return signal;
    }

    // @dev This function is called by the writeSignals function.
    // @dev Different rollups will have different ways of importing L1 data.
    // @dev This function should be implemented by the contract to match the rollup's needs
    // @param signal the signal to send
    function _sendSignal(bytes32 signal) internal virtual {}

    // view functions
    function l1Signaler() external view returns (address) {
        return _l1Signaler;
    }

    function nonce() external view returns (uint256) {
        return _nonce;
    }
}
