// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {SignalBoostOpStack} from "../src/SignalBoostImpl.sol";
import {SignalReceiver} from "../src/SignalReceiver.sol";
import {SignalProver} from "../src/SignalProver.sol";
import {ISignalBoost} from "../src/interfaces/ISignalBoost.sol";
import {DummyViewContract, DummyCrossDomainMessenger, L2PriceFeed} from "./DummyContracts.sol";

contract SignalBoostOpStackTest is Test {
    SignalBoostOpStack public signalBoost;
    DummyViewContract public dummyContract;
    DummyCrossDomainMessenger public crossDomainMessenger;
    SignalReceiver public signalReceiver;
    SignalProver public signalProver;
    L2PriceFeed public priceFeed;

    function setUp() public {
        // L1 contract that signals are sent to
        crossDomainMessenger = new DummyCrossDomainMessenger();

        // L2 contract that receives the signals
        signalReceiver = new SignalReceiver();

        // L2 contract that proves outputs based on signals
        signalProver = new SignalProver(address(signalReceiver));

        // L1 contract to batch signals for the l1Signaler
        signalBoost = new SignalBoostOpStack(address(crossDomainMessenger), address(signalReceiver));

        // The test contract that we can call view functions on
        dummyContract = new DummyViewContract();

        // A dummy L2 contract that demos how to fetch L1 data on L2
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
        (, bytes32 root) = writeSignals();

        // Verify that the signal was received by the L2 receiver
        assertEq(signalReceiver.signalReceived(root), true, "Signal was not properly forwarded to L2");
    }

    function test_ProveSignals() public {
        // Create signal requests for all three view functions
        (ISignalBoost.SignalRequest[] memory requests,) = writeSignals();

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
