// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DummyViewContract} from "./DummyViewContract.sol";
import {SignalBoost} from "../src/SignalBoost.sol";
import {ISignalBoost} from "../src/ISignalBoost.sol";
import {MerkleTree} from "../src/lib/MerkleTree.sol";

contract SignalBoostTester is SignalBoost {
    bytes32 public lastSignal;

    constructor(address signalReceiver_, address owner_) 
        SignalBoost(signalReceiver_, owner_) 
    {}

    // dummy implementation for testing
    function _sendSignal(bytes32 signal) internal override {
        lastSignal = signal;
    }
} 

contract SignalBoostTest is Test {
    SignalBoostTester public signalBoost;
    DummyViewContract public dummyContract;
    address public owner;
    address public signalReceiver;

    function setUp() public {
        owner = makeAddr("owner");
        signalReceiver = makeAddr("signalReceiver");
        signalBoost = new SignalBoostTester(signalReceiver, owner);
        dummyContract = new DummyViewContract();
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
        // Verify that a signal was stored
        assertTrue(signalBoost.lastSignal() != bytes32(0));
        assertEq(signalBoost.lastSignal(), root);
    }

    function test_VerifyMerkleRoot() public {
        // Write signals
        (ISignalBoost.SignalRequest[] memory requests, bytes32 expectedRoot) = writeSignals();

        // Get the individual signal hashes
        bytes32[] memory signals = new bytes32[](3);
        
        // Get uint256 signal
        bytes memory output0 = abi.encode(dummyContract.getDummyUint());
        signals[0] = keccak256(abi.encode(requests[0], output0));

        // Get bytes signal
        bytes memory output1 = abi.encode(dummyContract.getDummyBytes());
        signals[1] = keccak256(abi.encode(requests[1], output1));

        // Get bytes32 signal
        bytes memory output2 = abi.encode(dummyContract.getDummyBytes32());
        signals[2] = keccak256(abi.encode(requests[2], output2));

        // Generate Merkle root locally
        bytes32 localRoot = MerkleTree.generateTree(signals);

        // Verify that both roots match
        assertEq(localRoot, expectedRoot, "Merkle roots do not match");
    }
}
