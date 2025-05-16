// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISignalBoost {
    /// @notice Request for an L1 contract to be batched.
    struct Call {
        /// @notice The address to call.
        address to;
        /// @notice The value to send with the call.
        uint256 value;
        /// @notice The data to send with the call.
        bytes data;
        /// @notice The expected account that is executing the call.
        /// @dev This is used to ensure that a Call cannot be unbatched.
        /// @dev If the batch contains [alice, bob] destined for charlie to execute,
        /// @dev setting charlie as the batcher prevents alice's tx from being unbatched and
        /// @dev executed at her own account.
        address batcher;
    }

    function executeBatch(Call[] calldata calls) external;
    function executeBatchWithSig(
        Call[] calldata calls,
        bytes calldata signature
    ) external;
    function nonce() external view returns (uint256);

    /// @notice Emitted for every individual call executed.
    event CallExecuted(
        address indexed sender,
        address indexed to,
        uint256 value,
        bytes data
    );
    /// @notice Emitted when a full batch is executed.
    event BatchExecuted(uint256 indexed nonce, Call[] calls);

    // errors
    error NotOwner();
    error InvalidSignature();
    error InvalidNonce();
    error BatcherMismatch();
    error CallReverted();
}
