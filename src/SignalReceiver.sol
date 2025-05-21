// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISignalReceiver} from "./interfaces/ISignalReceiver.sol";

contract SignalReceiver is ISignalReceiver {
    mapping(bytes32 signal => bool received) private _signals;

    // todo checks to ensure only the rollup/sequencer can call this function
    function receiveSignal(bytes32 signal) external {
        _signals[signal] = true;
    }

    function signalReceived(bytes32 signal) external view returns (bool) {
        return _signals[signal];
    }
}
