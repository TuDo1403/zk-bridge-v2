// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ISNARKBridge} from "./ISNARKBridge.sol";

interface IECDSABridge is ISNARKBridge {
    function validators() external view returns (address[] memory validators_);
}
