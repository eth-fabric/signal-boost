// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {Test} from "forge-std/Test.sol";
import {SignalBoost} from "../src/SignalBoost.sol";
import {ISignalBoost} from "../src/interfaces/ISignalBoost.sol";
import {IBatcher} from "../src/interfaces/IBatcher.sol";
import {IBatcherBase} from "../src/interfaces/IBatcherBase.sol";
import {Batcher} from "../src/Batcher.sol";
import {SignalBoostTester} from "./DummyContracts.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract DumbOracle {
    uint256 private _price;

    function setPrice(uint256 price_) external returns (uint256) {
        _price = price_;
        return _price;
    }

    function getPrice() external view returns (uint256) {
        return _price;
    }
}

contract MockSignalService {
    bytes32 private _signal;

    function sendSignal(bytes32 signal_) external returns (bytes32 slot) {
        _signal = signal_;
        return bytes32("0x1337");
    }

    function getSignal() external view returns (bytes32) {
        return _signal;
    }
}

contract BatcherHelpers is Test {
    /**
     * @dev Helper function to encode multiple calls into a single bytes array
     * @param calls Array of calls to encode
     * @return Encoded bytes representation of the calls
     */
    function encodeCalls(IBatcher.Call[] memory calls) internal returns (bytes memory) {
        bytes memory encodedCalls = "";
        for (uint256 i = 0; i < calls.length; i++) {
            encodedCalls = abi.encodePacked(encodedCalls, calls[i].to, calls[i].value, calls[i].data, calls[i].batcher);
        }
        return encodedCalls;
    }

    /**
     * @dev Helper function to sign a batch of calls
     * @param privateKey The private key of the signer
     * @param calls The calls to sign
     * @param nonce The nonce of the signer
     * @return signature The signed batch of calls
     */
    function signBatch(uint256 privateKey, IBatcher.Call[] memory calls, uint256 nonce)
        internal
        returns (bytes memory signature)
    {
        bytes memory encodedCalls = encodeCalls(calls);
        bytes32 digest = keccak256(abi.encodePacked(nonce, encodedCalls));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, MessageHashUtils.toEthSignedMessageHash(digest));
        signature = abi.encodePacked(r, s, v);
    }
}

/**
 * @title BatcherTest
 * @dev Test contract for Batcher functionality
 */
contract BasicBatcherTest is BatcherHelpers {
    address alice;
    uint256 alicePrivateKey;
    uint256 aliceInitialBalance;
    address bob;
    uint256 bobPrivateKey;
    uint256 bobInitialBalance;

    function setUp() public {
        (alice, alicePrivateKey) = makeAddrAndKey("alice");
        (bob, bobPrivateKey) = makeAddrAndKey("bob");
        aliceInitialBalance = 100 ether;
        bobInitialBalance = 100 ether;
        vm.deal(alice, aliceInitialBalance);
        vm.deal(bob, bobInitialBalance);

        // Create the Batcher instance
        Batcher batcher = new Batcher();

        // Set the Batcher as the 7702 account
        vm.signAndAttachDelegation(address(batcher), alicePrivateKey);
        vm.signAndAttachDelegation(address(batcher), bobPrivateKey);
    }

    /**
     * @dev Test basic contract deployment with 7702
     */
    function test_deploy() public {
        require(address(alice).code.length != 0);
        require(address(bob).code.length != 0, "interface works");
    }

    /**
     * @dev Test basic ETH transfer functionality works despite 7702
     */
    function test_basicTransfer() public {
        vm.prank(alice);
        (bool success,) = bob.call{value: 1 ether}("");
        require(success, "transfer failed");
        assertEq(bob.balance, bobInitialBalance + 1 ether);
        assertEq(alice.balance, aliceInitialBalance - 1 ether);
    }

    /**
     * @dev Test batch ETH transfers initiated by the owner
     */
    function test_executeBatch() public {
        // Alice pre-signs an ETH transfer to Bob
        address dest1 = makeAddr("dest1");
        address dest2 = makeAddr("dest2");
        IBatcherBase.Call[] memory calls = new IBatcherBase.Call[](2);
        calls[0] = IBatcherBase.Call({to: dest1, value: 1 ether, data: "", batcher: alice});
        calls[1] = IBatcherBase.Call({to: dest2, value: 1 ether, data: "", batcher: alice});

        // Alice submits the call
        vm.prank(alice);
        IBatcher(address(alice)).executeBatch(calls);

        // Verify the transfer was executed
        assertEq(dest1.balance, 1 ether);
        assertEq(dest2.balance, 1 ether);
    }

    /**
     * @dev Test batch ETH transfer functionality using executeBatchWithSig, submitted by a non-owner
     */
    function test_executeBatchWithSig() public {
        address dest1 = makeAddr("dest1");
        address dest2 = makeAddr("dest2");

        // Create two transfer calls
        IBatcherBase.Call[] memory calls = new IBatcherBase.Call[](2);
        calls[0] = IBatcherBase.Call({to: dest1, value: 1 ether, data: "", batcher: bob});
        calls[1] = IBatcherBase.Call({to: dest2, value: 1 ether, data: "", batcher: bob});

        // Encode and sign the batch
        bytes memory signature = signBatch(alicePrivateKey, calls, IBatcher(address(alice)).nonce());

        // Execute the batch
        vm.prank(bob); // bob executes on behalf of alice
        IBatcher(address(alice)).executeBatchWithSig(calls, signature);

        // Verify balances
        assertEq(dest1.balance, 1 ether);
        assertEq(dest2.balance, 1 ether);
    }

    /**
     * @dev Test batch ETH transfer functionality using executeBatchWithSig, submitted by the owner
     */
    function test_executeBatchWithSig_batcherMismatch() public {
        address batcher = makeAddr("batcher");

        // Create a transfer call
        IBatcherBase.Call[] memory calls = new IBatcherBase.Call[](1);
        calls[0] = IBatcherBase.Call({to: batcher, value: 1 ether, data: "", batcher: batcher});

        // Encode and sign the batch
        bytes memory signature = signBatch(alicePrivateKey, calls, IBatcher(address(alice)).nonce());

        // Execute the batch
        vm.prank(bob); // bob executes instead of batcher
        vm.expectRevert(IBatcherBase.BatcherMismatch.selector);
        IBatcher(address(alice)).executeBatchWithSig(calls, signature);
    }

    /**
     * @dev Test executeBatchWithSig reverts if a call is unbatched
     */
    function test_executeBatchWithSig_invalidSignature() public {
        address dest1 = makeAddr("dest1");
        address dest2 = makeAddr("dest2");

        // Create two transfer calls
        IBatcherBase.Call[] memory calls = new IBatcherBase.Call[](2);
        calls[0] = IBatcherBase.Call({to: dest1, value: 1 ether, data: "", batcher: bob});
        calls[1] = IBatcherBase.Call({to: dest2, value: 1 ether, data: "", batcher: bob});

        // Encode and sign the batch
        bytes memory signature = signBatch(alicePrivateKey, calls, IBatcher(address(alice)).nonce());

        // Attempt to unbatch the 2nd call
        IBatcherBase.Call[] memory calls2 = new IBatcherBase.Call[](1);
        calls2[0] = calls[0];

        // Execute the batch
        vm.prank(bob); // bob executes on behalf of alice
        vm.expectRevert(IBatcherBase.InvalidSignature.selector);
        IBatcher(address(alice)).executeBatchWithSig(calls2, signature);
    }

    /**
     * @dev Test a nested batch of calls, assuming all accounts are Signalers
     */
    function test_nestedBatchExecuteWithSig() public {
        // Charlie is the end recipient of the eth transfers
        address charlie = makeAddr("charlie");

        // Bob pre-signs an ETH transfer to Charlie
        IBatcherBase.Call[] memory subCalls = new IBatcherBase.Call[](1);
        subCalls[0] = IBatcherBase.Call({
            to: charlie,
            value: 1 ether,
            data: "",
            batcher: alice // this call is nested in Alice's batch
        });
        bytes memory subSignature = signBatch(bobPrivateKey, subCalls, IBatcher(address(bob)).nonce());

        // Verify this call cannot be sent as a standalone batch
        vm.prank(bob);
        vm.expectRevert(IBatcherBase.BatcherMismatch.selector);
        IBatcher(address(bob)).executeBatchWithSig(subCalls, subSignature);

        // Encode Bob's eth transfer as an executeBatch() call that will be executed in Alice's batch
        IBatcherBase.Call[] memory calls = new IBatcherBase.Call[](2);
        calls[0] = IBatcherBase.Call({
            to: bob,
            value: 0,
            data: abi.encodeCall(IBatcher.executeBatchWithSig, (subCalls, subSignature)),
            batcher: alice // alice will submit her own batch
        });

        calls[1] = IBatcherBase.Call({
            to: charlie,
            value: 1 ether,
            data: "",
            batcher: alice // alice will submit her own batch
        });

        // Execute the batch (no signature required since Alice is the submitter)
        vm.prank(alice);
        IBatcher(address(alice)).executeBatch(calls);

        // Verify the transfer was executed
        assertEq(alice.balance, aliceInitialBalance - 1 ether);
        assertEq(bob.balance, bobInitialBalance - 1 ether);
        assertEq(charlie.balance, 2 ether);
    }
}

/**
 * @title BatcherTest
 * @dev Test contract for Batcher functionality
 */
contract BatcherWithSignalBoostTest is BatcherHelpers {
    address alice;
    uint256 alicePrivateKey;
    uint256 aliceInitialBalance;
    address bob;
    uint256 bobPrivateKey;
    uint256 bobInitialBalance;

    SignalBoostTester public signalBoost;
    DumbOracle public l1Oracle;

    function setUp() public {
        (alice, alicePrivateKey) = makeAddrAndKey("alice");
        (bob, bobPrivateKey) = makeAddrAndKey("bob");
        aliceInitialBalance = 100 ether;
        bobInitialBalance = 100 ether;
        vm.deal(alice, aliceInitialBalance);
        vm.deal(bob, bobInitialBalance);

        // Create the Batcher instance
        Batcher batcher = new Batcher();

        // Set the Batcher as the 7702 account
        vm.signAndAttachDelegation(address(batcher), alicePrivateKey);
        vm.signAndAttachDelegation(address(batcher), bobPrivateKey);

        signalBoost = new SignalBoostTester();
        l1Oracle = new DumbOracle();
    }

    /**
     * @dev Test basic contract deployment with 7702
     */
    function test_deploy() public {
        require(address(alice).code.length != 0);
        require(address(bob).code.length != 0, "interface works");
    }

    function test_signalBoostRelaysLatestOraclePrice() public {
        uint256 price = 42;

        // Start the batch
        IBatcherBase.Call[] memory calls = new IBatcherBase.Call[](2);

        // Set the oracle's price to 42 as a transaction in the batch
        calls[0] = IBatcherBase.Call({
            to: address(l1Oracle),
            value: 0,
            data: abi.encodeWithSelector(l1Oracle.setPrice.selector, price),
            batcher: bob
        });

        // A request for the oracle's latest price
        ISignalBoost.SignalRequest[] memory requests = new ISignalBoost.SignalRequest[](1);
        requests[0] = ISignalBoost.SignalRequest({
            target: address(l1Oracle),
            selector: bytes4(keccak256("getPrice()")),
            input: ""
        });

        // Add call to SignalBoost.writeSignals() to batch
        calls[1] = IBatcherBase.Call({
            to: address(signalBoost),
            value: 0,
            data: abi.encodeWithSelector(signalBoost.writeSignals.selector, requests),
            batcher: bob
        });

        // Encode and sign the batch
        bytes memory signature = signBatch(alicePrivateKey, calls, IBatcher(address(alice)).nonce());

        // Delegate batch execution using a signature
        vm.prank(bob); // not owner
        IBatcher(address(alice)).executeBatchWithSig(calls, signature);

        // Verify the price was set, implying the batch was successful
        assertEq(l1Oracle.getPrice(), price, "price was not set");

        // Verify the signal was sent
        bytes32 signal = signalBoost.lastSignal();
        bytes[] memory outputs = new bytes[](1);
        outputs[0] = abi.encode(price);
        bytes32 signalRequestsRoot = keccak256(abi.encode(requests, outputs));
        assertEq(signal, signalRequestsRoot, "signal was not sent");
    }
}
