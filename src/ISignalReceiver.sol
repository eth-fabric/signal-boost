// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISignalReceiver {
    function receiveSignal(bytes32 signal) external;
    function signalReceived(bytes32 signal) external view returns (bool);
}
