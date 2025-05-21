// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBatcherBase} from "./IBatcherBase.sol";

interface ITobascoBatcher is IBatcherBase {
    function executeBatch(Call[] calldata calls, uint256 _expectedBlockNumber) external;
    function executeBatchWithSig(Call[] calldata calls, bytes calldata signature, uint256 _expectedBlockNumber)
        external;
}
