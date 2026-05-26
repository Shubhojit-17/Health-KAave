// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {AaveHealthHook} from "../src/AaveHealthHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

contract DeployHook is Script {
    function run() external {
        address poolManagerAddr = vm.envAddress("POOL_MANAGER_TESTNET");
        require(poolManagerAddr != address(0), "Set POOL_MANAGER_TESTNET in .env");

        // On testnet, Aave is not deployed. Use deployer address as dummy.
        // The hook's try/catch handles this gracefully and falls back to STANDARD_FEE.
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address dummyAavePool = vm.addr(deployerKey);

        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        bytes memory constructorArgs = abi.encode(poolManagerAddr, dummyAavePool);

        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_FACTORY, flags, type(AaveHealthHook).creationCode, constructorArgs);

        console2.log("Mined Hook Address:", hookAddress);
        console2.log("Salt:");
        console2.logBytes32(salt);

        vm.startBroadcast();

        AaveHealthHook hook = new AaveHealthHook{salt: salt}(IPoolManager(poolManagerAddr), dummyAavePool);

        console2.log("AaveHealthHook deployed at:", address(hook));
        require(address(hook) == hookAddress, "Hook address mismatch -- salt mining failed");

        vm.stopBroadcast();
    }
}
