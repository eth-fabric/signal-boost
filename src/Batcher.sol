// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BatcherBase} from "./BatcherBase.sol";
import {IBatcher} from "./interfaces/IBatcher.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract Batcher is BatcherBase, IBatcher {
    /**
     * /**
     * @notice Executes a batch of calls initiated by the account owner.
     * @param calls An array of Call structs containing destination, ETH value, and calldata.
     */
    function executeBatch(Call[] calldata calls) external {
        if (msg.sender != address(this)) revert NotOwner();
        _executeBatch(calls);
    }

    /**
     * @notice Executes a batch of calls using an off–chain signature.
     * @param calls An array of Call structs containing destination, ETH value, and calldata.
     * @param signature The ECDSA signature over the current nonce and the call data.
     *
     * The signature must be produced off–chain by signing:
     * The signing key should be the account's key (which becomes the smart account's own identity after upgrade).
     */
    function executeBatchWithSig(Call[] calldata calls, bytes calldata signature) external {
        // Compute the digest that the account was expected to sign.
        bytes memory encodedCalls;
        for (uint256 i = 0; i < calls.length; i++) {
            encodedCalls = abi.encodePacked(encodedCalls, calls[i].to, calls[i].value, calls[i].data, calls[i].batcher);
        }
        bytes32 digest = keccak256(abi.encodePacked(_nonce, encodedCalls));

        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(digest);

        // Recover the signer from the provided signature.
        address recovered = ECDSA.recover(ethSignedMessageHash, signature);
        if (recovered != address(this)) revert InvalidSignature();

        _executeBatch(calls);
    }
}
