// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SignalBoost} from "./SignalBoost.sol";

// --------------------TAIKO-----------------------------------

interface ISignalService {
    function sendSignal(bytes32 signal) external returns (bytes32 slot);
}

contract SignalBoostTaiko is SignalBoost {
    address private _signalService;

    constructor(address signalService_) SignalBoost() {
        _signalService = signalService_;
    }

    function signalService() external view returns (address) {
        return _signalService;
    }

    function _sendSignal(bytes32 signal) internal override {
        ISignalService(_signalService).sendSignal(signal);
    }
}

// --------------------OP STACK-----------------------------------

interface ICrossDomainMessenger {
    function sendMessage(address _target, bytes calldata _message, uint32 _minGasLimit) external payable;
}

contract SignalBoostOpStack is SignalBoost {
    address private _crossDomainMessenger;
    address private _signalReceiver;

    constructor(address crossDomainMessenger_, address signalReceiver_) SignalBoost() {
        _crossDomainMessenger = crossDomainMessenger_;
        _signalReceiver = signalReceiver_;
    }

    function _sendSignal(bytes32 signal) internal override {
        ICrossDomainMessenger(_crossDomainMessenger).sendMessage(
            _signalReceiver,
            abi.encode(signal),
            100000 // TODO: Set a proper minGasLimit
        );
    }
}
