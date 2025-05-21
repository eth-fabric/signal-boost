// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DummyViewContract, SignalBoostTester} from "./DummyContracts.sol";
import {SignalBoost} from "../src/SignalBoost.sol";
import {ISignalBoost} from "../src/interfaces/ISignalBoost.sol";

contract SignalBoostTest is Test {
    SignalBoostTester public signalBoost;
    DummyViewContract public dummyContract;

    function setUp() public {
        signalBoost = new SignalBoostTester();
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
        (, bytes32 root) = writeSignals();
        // Verify that a signal was stored
        assertTrue(signalBoost.lastSignal() != bytes32(0));
        assertEq(signalBoost.lastSignal(), root);
    }

    function test_VerifySignal() public {
        // Write signals
        (ISignalBoost.SignalRequest[] memory requests, bytes32 expectedRoot) = writeSignals();
        bytes[] memory outputs = new bytes[](requests.length);

        // Get uint256 signal
        outputs[0] = abi.encode(dummyContract.getDummyUint());

        // Get bytes signal
        outputs[1] = abi.encode(dummyContract.getDummyBytes());

        // Get bytes32 signal
        outputs[2] = abi.encode(dummyContract.getDummyBytes32());

        // Hash the requests and outputs
        bytes32 signalRequestsRoot = keccak256(abi.encode(requests, outputs));

        // Verify that both roots match
        assertEq(signalRequestsRoot, expectedRoot, "Signal requests roots do not match");
    }
}
