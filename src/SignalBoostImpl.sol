// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SignalBoost} from "./SignalBoost.sol";

interface ISignalService {
    function sendSignal(bytes32 signal) external returns (bytes32 slot);
}

contract SignalBoostTaiko is SignalBoost {
    constructor(address signalReceiver_) SignalBoost(signalReceiver_) {}

    function _sendSignal(bytes32 signal) internal override {
        ISignalService(_signalReceiver).sendSignal(signal);
    }
}

interface ICrossDomainMessenger {
    function sendMessage(address _target, bytes calldata _message, uint32 _minGasLimit) external payable;
}

contract SignalBoostOpStack is SignalBoost {
    address private _signalReceiverL2;

    constructor(address signalReceiver_, address signalReceiverL2_) SignalBoost(signalReceiver_) {
        _signalReceiverL2 = signalReceiverL2_;
    }

    function _sendSignal(bytes32 signal) internal override {
        ICrossDomainMessenger(_signalReceiver).sendMessage(
            _signalReceiverL2,
            abi.encode(signal),
            100000 // TODO: Set a proper minGasLimit
        );
    }
}
