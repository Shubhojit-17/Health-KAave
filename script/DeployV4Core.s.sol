// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";

contract DeployV4Core is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying PoolManager from:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        PoolManager poolManager = new PoolManager(deployer);

        console2.log("PoolManager deployed at:", address(poolManager));
        console2.log("Owner:", deployer);

        vm.stopBroadcast();
    }
}
