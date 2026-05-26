// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IPositionDescriptor} from "@uniswap/v4-periphery/src/interfaces/IPositionDescriptor.sol";
import {IWETH9} from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";
import {PositionManager} from "@uniswap/v4-periphery/src/PositionManager.sol";

contract DeployPositionManager is Script {
    function run() external {
        address poolManagerAddr = vm.envAddress("POOL_MANAGER_TESTNET");
        address permit2Addr = vm.envAddress("PERMIT2");

        require(poolManagerAddr != address(0), "Set POOL_MANAGER_TESTNET in .env");

        vm.startBroadcast();

        PositionManager posManager = new PositionManager(
            IPoolManager(poolManagerAddr),
            IAllowanceTransfer(permit2Addr),
            300_000,
            IPositionDescriptor(address(0)),
            IWETH9(address(0))
        );

        console2.log("PositionManager deployed at:", address(posManager));

        vm.stopBroadcast();
    }
}
