// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {MyToken} from "../../src/MyToken.sol";

/**
 * @dev Deploy script for MyToken contract
 */
contract MyTokenDeploy is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY_DEPLOYER"));
        new MyToken();
        vm.stopBroadcast();
    }
}