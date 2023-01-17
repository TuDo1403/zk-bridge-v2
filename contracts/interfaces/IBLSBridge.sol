// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ISNARKBridge} from "./ISNARKBridge.sol";

interface IBLSBridge is ISNARKBridge {
    function validators() external view returns (uint256[4][] memory);
}
