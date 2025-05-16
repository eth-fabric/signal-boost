// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISignalReceiver} from "../src/ISignalReceiver.sol";
import {ISignalBoost} from "../src/ISignalBoost.sol";
import {ISignalProver} from "../src/ISignalProver.sol";
import {ISignalService, ICrossDomainMessenger} from "../src/SignalBoostImpl.sol";

contract DummyViewContract {
    uint256 private _dummyUint = 42;
    bytes private _dummyBytes = hex"123456";
    bytes32 private _dummyBytes32 = keccak256("dummy");

    function getDummyUint() external view returns (uint256) {
        return _dummyUint;
    }

    function getDummyBytes() external view returns (bytes memory) {
        return _dummyBytes;
    }

    function getDummyBytes32() external view returns (bytes32) {
        return _dummyBytes32;
    }
}

// Dummy cross-domain messenger that just forwards messages to the SignalReceiver contract
// In practice the rollup's derivation process is responsible for forwarding the messages
contract DummyCrossDomainMessenger is ICrossDomainMessenger {
    function sendMessage(address _target, bytes calldata _message, uint32 _minGasLimit) external payable {
        // Decode the signal from the message
        bytes32 signal = abi.decode(_message, (bytes32));

        // Forward the signal to the target
        ISignalReceiver(_target).receiveSignal(signal);
    }
}

// Dummy signal service that just forwards signals to the SignalReceiver contract
// In practice the rollup's derivation process is responsible for forwarding the signals
contract DummySignalService is ISignalService {
    address public signalReceiver;

    constructor(address signalReceiver_) {
        signalReceiver = signalReceiver_;
    }

    function sendSignal(bytes32 signal) external returns (bytes32 slot) {
        // Forward the signal to the target
        ISignalReceiver(signalReceiver).receiveSignal(signal);
    }
}

// example making the L1 price feed available on L2
// Note that the L2 user is doesn't need to understand about SignalBoost as
// long as they trust the SignalProver data
contract L2PriceFeed {
    address _l1Oracle;
    address _signalProver;

    constructor(address l1Oracle_, address signalProver_) {
        _l1Oracle = l1Oracle_;
        _signalProver = signalProver_;
    }

    function getOraclePrice() external view returns (uint256) {
        // Recreate the signal request
        ISignalBoost.SignalRequest memory request =
            ISignalBoost.SignalRequest({target: _l1Oracle, selector: bytes4(keccak256("getDummyUint()")), input: ""});

        bytes32 requestHash = keccak256(abi.encode(request));

        // Call the signal prover
        bytes memory output = ISignalProver(_signalProver).getOutput(requestHash);

        // Decode the output
        return abi.decode(output, (uint256));
    }
}
