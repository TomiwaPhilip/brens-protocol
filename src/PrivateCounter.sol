// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { FHE, euint32 } from "../lib/fhenix-contracts/contracts/FHE.sol";

contract PrivateCounter {
    euint32 private count;
    
    function increment() public {
        count = count + FHE.asEuint32(1);
    }
    
    function getCount() public view returns (euint32) {
        return count;
    }
}
