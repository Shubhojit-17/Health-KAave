// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {AaveHealthHook} from "../src/AaveHealthHook.sol";

contract MineHookAddressScript is Script {
    function run() external view {
        address POOL_MANAGER = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        address AAVE_POOL = 0xdFf435BCcf782f11187D3a4454d96702eD78e092;

        require(POOL_MANAGER != address(0), "Set POOL_MANAGER address");
        require(AAVE_POOL != address(0), "Set AAVE_POOL address");

        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);

        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_FACTORY,
            flags,
            type(AaveHealthHook).creationCode,
            abi.encode(POOL_MANAGER, AAVE_POOL)
        );

        console2.log("Hook Address:", hookAddress);
        console2.log("Salt (bytes32):");
        console2.logBytes32(salt);
        console2.log("Save both values -- you need them for DeployHook.s.sol");
    }
}
