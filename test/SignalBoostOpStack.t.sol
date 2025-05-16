// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SignalBoostOpStack} from "../src/SignalBoostImpl.sol";
import {DummyViewContract} from "./DummyViewContract.sol";
import {ISignalBoost} from "../src/ISignalBoost.sol";
import {MerkleTree} from "../src/lib/MerkleTree.sol";
// Dummy cross-domain messenger that just forwards messages

contract DummyCrossDomainMessenger {
    function sendMessage(address _target, bytes calldata _message, uint32 _minGasLimit) external payable {
        // Decode the signal from the message
        bytes32 signal = abi.decode(_message, (bytes32));

        // Forward the signal to the target
        ISignalReceiverL2(_target).receiveSignal(signal);
    }
}

interface ISignalReceiverL2 {
    function receiveSignal(bytes32 signal) external;
    function lastSignal() external view returns (bytes32);
}

// Simple L2 contract that receives and stores signals relayed by the cross-domain messenger
contract SignalReceiverL2 {
    bytes32 private _lastSignal;

    function receiveSignal(bytes32 signal) external {
        _lastSignal = signal;
    }

    function lastSignal() external view returns (bytes32) {
        return _lastSignal;
    }
}

interface ISignalProver {
    function getOutput(bytes32 requestHash) external view returns (bytes memory);
}

// Contract that verifies signals against the stored root
contract SignalProver {
    // Mapping from request hash to output
    mapping(bytes32 requestHash => bytes output) public requestOutputs;
    ISignalReceiverL2 public signalReceiver;

    constructor(address signalReceiver_) {
        signalReceiver = ISignalReceiverL2(signalReceiver_);
    }

    function proveSignals(ISignalBoost.SignalRequest[] calldata requests, bytes[] calldata outputs) external {
        require(requests.length == outputs.length, "Length mismatch");

        // Generate signal hashes
        bytes32[] memory signals = new bytes32[](requests.length);
        for (uint256 i = 0; i < requests.length; i++) {
            signals[i] = keccak256(abi.encode(requests[i], outputs[i]));
        }

        // Generate Merkle root
        bytes32 root = MerkleTree.generateTree(signals);

        // Verify against stored root
        require(root == signalReceiver.lastSignal(), "Root mismatch");

        // Store each request's output
        for (uint256 i = 0; i < requests.length; i++) {
            bytes32 requestHash = keccak256(abi.encode(requests[i]));
            requestOutputs[requestHash] = outputs[i];
        }
    }

    function getOutput(bytes32 requestHash) external view returns (bytes memory) {
        return requestOutputs[requestHash];
    }
}

// example making the L1 price feed available on L2
contract L2PriceFeed {
    address _l1Oracle;
    address _signalProver;

    constructor(address l1Oracle_, address signalProver_) {
        _l1Oracle = l1Oracle_;
        _signalProver = signalProver_;
    }

    function getOraclePrice() external returns (uint256) {
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

contract SignalBoostOpStackTest is Test {
    SignalBoostOpStack public signalBoost;
    DummyViewContract public dummyContract;
    DummyCrossDomainMessenger public messenger;
    SignalReceiverL2 public signalReceiverL2;
    SignalProver public signalProver;
    L2PriceFeed public priceFeed;
    address public owner;
    address public signalReceiver;

    function setUp() public {
        owner = makeAddr("owner");
        signalReceiver = makeAddr("signalReceiver");
        messenger = new DummyCrossDomainMessenger();
        signalReceiverL2 = new SignalReceiverL2();
        signalProver = new SignalProver(address(signalReceiverL2));
        signalBoost = new SignalBoostOpStack(address(messenger), address(signalReceiverL2));

        dummyContract = new DummyViewContract();
        priceFeed = new L2PriceFeed(address(dummyContract), address(signalProver));
    }

    function writeSignals() internal returns (ISignalBoost.SignalRequest[] memory, bytes32) {
        // Create signal requests for all three view functions
        ISignalBoost.SignalRequest[] memory requests = new ISignalBoost.SignalRequest[](3);

        // Request for getDummyUint
        requests[0] = ISignalBoost.SignalRequest({
            target: address(dummyContract),
            selector: bytes4(keccak256("getDummyUint()")),
            input: ""
        });

        // Request for getDummyBytes
        requests[1] = ISignalBoost.SignalRequest({
            target: address(dummyContract),
            selector: bytes4(keccak256("getDummyBytes()")),
            input: ""
        });

        // Request for getDummyBytes32
        requests[2] = ISignalBoost.SignalRequest({
            target: address(dummyContract),
            selector: bytes4(keccak256("getDummyBytes32()")),
            input: ""
        });

        // Call writeSignals
        bytes32 root = signalBoost.writeSignals(requests);

        return (requests, root);
    }

    function test_WriteSignals() public {
        (ISignalBoost.SignalRequest[] memory requests, bytes32 root) = writeSignals();

        // Verify that the signal was received by the L2 receiver
        assertEq(signalReceiverL2.lastSignal(), root, "Signal was not properly forwarded to L2");
    }

    function test_ProveSignals() public {
        // Create signal requests for all three view functions
        (ISignalBoost.SignalRequest[] memory requests, bytes32 expectedRoot) = writeSignals();

        // Get the outputs
        bytes[] memory outputs = new bytes[](3);
        outputs[0] = abi.encode(dummyContract.getDummyUint());
        outputs[1] = abi.encode(dummyContract.getDummyBytes());
        outputs[2] = abi.encode(dummyContract.getDummyBytes32());

        // Prove the signals
        signalProver.proveSignals(requests, outputs);

        // Verify we can retrieve the outputs
        assertEq(signalProver.getOutput(keccak256(abi.encode(requests[0]))), outputs[0], "Output mismatch for uint");
        assertEq(signalProver.getOutput(keccak256(abi.encode(requests[1]))), outputs[1], "Output mismatch for bytes");
        assertEq(signalProver.getOutput(keccak256(abi.encode(requests[2]))), outputs[2], "Output mismatch for bytes32");

        // Verify the price feed
        // Note that the L2 user is doesn't need to understand about SignalBoost as
        // long as they trust the SignalProver data
        assertEq(priceFeed.getOraclePrice(), 42, "Price mismatch");
    }
}
