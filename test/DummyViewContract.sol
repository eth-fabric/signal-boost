// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

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