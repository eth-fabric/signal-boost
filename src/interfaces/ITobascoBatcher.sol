// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBatcherBase} from "./IBatcherBase.sol";
import {ITobasco} from "tobasco/src/ITobasco.sol";

interface ITobascoBatcher is IBatcherBase, ITobasco {
    function executeBatch(Call[] calldata calls, uint256 _expectedBlockNumber) external;
    function executeBatchWithSig(Call[] calldata calls, bytes calldata signature, uint256 _expectedBlockNumber)
        external;
}
