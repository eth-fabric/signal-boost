// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBatcherBase} from "./interfaces/IBatcherBase.sol";

contract BatcherBase is IBatcherBase {
    uint256 internal _nonce;

    // Allow the contract to receive ETH
    fallback() external payable {}
    receive() external payable {}

    // internal functions
    function _executeBatch(Call[] calldata calls) internal {
        uint256 currentNonce = _nonce;
        _nonce++; // Increment nonce to protect against replay attacks

        for (uint256 i = 0; i < calls.length; i++) {
            _executeCall(calls[i]);
        }

        emit BatchExecuted(currentNonce, calls);
    }

    function _executeCall(Call calldata call) internal {
        if (call.batcher != msg.sender) revert BatcherMismatch();

        (bool success,) = call.to.call{value: call.value}(call.data);
        if (!success) revert CallReverted();

        emit CallExecuted(msg.sender, call.to, call.value, call.data);
    }

    function nonce() external view returns (uint256) {
        return _nonce;
    }
}
