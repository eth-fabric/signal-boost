// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {Test} from "forge-std/Test.sol";
import {SignalBoost} from "../src/SignalBoost.sol";
import {ISignalBoost} from "../src/interfaces/ISignalBoost.sol";
import {ITobascoBatcher} from "../src/interfaces/ITobascoBatcher.sol";
import {IBatcherBase} from "../src/interfaces/IBatcherBase.sol";
import {TobascoBatcher} from "../src/TobascoBatcher.sol";
import {Batcher} from "../src/Batcher.sol";
import {SignalBoostTester} from "./DummyContracts.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract TobascoBatcherTester is TobascoBatcher {
    uint256 public gasLeftAmount;

    function _gasleft() internal override returns (uint256) {
        if (gasLeftAmount > 0) {
            // By default Foundry is consuming gas so the default gasleft()
            // is too low during unit tests. This is a hack to fix that.
            return gasLeftAmount;
        }
        return gasleft();
    }

    function setGasLeftAmount(uint256 _gasLeftAmount) public {
        gasLeftAmount = _gasLeftAmount;
    }
}

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

contract BatcherHelpers is Test {
    /**
     * @dev Helper function to encode multiple calls into a single bytes array
     * @param calls Array of calls to encode
     * @return Encoded bytes representation of the calls
     */
    function encodeCalls(IBatcherBase.Call[] memory calls) internal returns (bytes memory) {
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
    function signBatch(uint256 privateKey, IBatcherBase.Call[] memory calls, uint256 nonce)
        internal
        returns (bytes memory signature)
    {
        bytes memory encodedCalls = encodeCalls(calls);
        bytes32 digest = keccak256(abi.encodePacked(nonce, encodedCalls));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, MessageHashUtils.toEthSignedMessageHash(digest));
        signature = abi.encodePacked(r, s, v);
    }
}

contract TobascoBatcherWithSignalBoostTest is BatcherHelpers {
    address tobascoBatcher;
    uint256 tobascoBatcherPrivateKey;
    uint256 tobascoBatcherInitialBalance;
    address basicBatcher;
    uint256 basicBatcherPrivateKey;
    uint256 basicBatcherInitialBalance;

    SignalBoostTester public signalBoost;
    DumbOracle public l1Oracle;

    function setUp() public {
        (tobascoBatcher, tobascoBatcherPrivateKey) = makeAddrAndKey("tobascoBatcher");
        (basicBatcher, basicBatcherPrivateKey) = makeAddrAndKey("basicBatcher");
        tobascoBatcherInitialBalance = 100 ether;
        basicBatcherInitialBalance = 100 ether;
        vm.deal(tobascoBatcher, tobascoBatcherInitialBalance);
        vm.deal(basicBatcher, basicBatcherInitialBalance);

        // Create the TobascoBatcher instance
        TobascoBatcherTester tobascoBatcher = new TobascoBatcherTester();

        // Create the Batcher instance
        Batcher basicBatcher = new Batcher();

        // Set the Batcher as the 7702 account
        vm.signAndAttachDelegation(address(tobascoBatcher), tobascoBatcherPrivateKey);
        vm.signAndAttachDelegation(address(basicBatcher), basicBatcherPrivateKey);

        signalBoost = new SignalBoostTester();
        l1Oracle = new DumbOracle();
    }

    /**
     * @dev Test basic contract deployment with 7702
     */
    function test_deploy() public {
        require(address(tobascoBatcher).code.length != 0);
        require(address(basicBatcher).code.length != 0);
    }

    function test_signalBoostRelaysLatestOraclePrice() public {
        ITobascoBatcher tobasco = ITobascoBatcher(address(tobascoBatcher));

        // hack to fix the gasleft() issue in foundry tests
        // When tobasco.gasLeft() is called, this will return the amount of gas left
        // in the block after initiating the call.
        // tobasco.setGasLeftAmount(block.gaslimit - tobasco.getIntrinsicGasCost());
        address(tobascoBatcher).call(
            abi.encodeWithSelector(
                TobascoBatcherTester.setGasLeftAmount.selector, block.gaslimit - tobasco.getIntrinsicGasCost()
            )
        );

        // Oracle price to set
        uint256 price = 42;

        // Start the batch
        IBatcherBase.Call[] memory calls = new IBatcherBase.Call[](2);

        // Set the oracle's price to 42 as a transaction in the batch
        calls[0] = IBatcherBase.Call({
            to: address(l1Oracle),
            value: 0,
            data: abi.encodeWithSelector(l1Oracle.setPrice.selector, price),
            batcher: basicBatcher
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
            batcher: basicBatcher
        });

        // Encode and sign the batch
        bytes memory signature = signBatch(tobascoBatcherPrivateKey, calls, tobasco.nonce());

        // Delegate batch execution using a signature
        vm.prank(basicBatcher); // not owner
        tobasco.executeBatchWithSig(calls, signature, block.number);

        // Verify the price was set, implying the batch was successful
        assertEq(l1Oracle.getPrice(), price, "price was not set");

        // Verify the signal was sent
        bytes32 signal = signalBoost.lastSignal();
        bytes[] memory outputs = new bytes[](1);
        outputs[0] = abi.encode(price);
        bytes32 signalRequestsRoot = keccak256(abi.encode(requests, outputs));
    }
}
