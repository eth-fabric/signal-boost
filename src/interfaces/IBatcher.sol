// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBatcherBase} from "./IBatcherBase.sol";

interface IBatcher is IBatcherBase {
    function executeBatch(Call[] calldata calls) external;
    function executeBatchWithSig(Call[] calldata calls, bytes calldata signature) external;
}
