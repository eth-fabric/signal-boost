// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISignalBoost} from "./ISignalBoost.sol";

interface ISignalProver {
    function getOutput(bytes32 requestHash) external view returns (bytes memory);
    function getOutput(ISignalBoost.SignalRequest calldata request) external view returns (bytes memory);
    function proveSignals(ISignalBoost.SignalRequest[] calldata requests, bytes[] calldata outputs) external;

    error SignalDoesNotExist();
    error InputLengthMismatch();
}
