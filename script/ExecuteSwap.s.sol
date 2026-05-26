// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapHelper is IUnlockCallback {
    IPoolManager public immutable poolManager;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    function executeSwap(PoolKey memory key, SwapParams memory params, bytes memory hookData) external {
        IERC20(Currency.unwrap(key.currency0)).approve(address(poolManager), type(uint256).max);
        IERC20(Currency.unwrap(key.currency1)).approve(address(poolManager), type(uint256).max);

        poolManager.unlock(abi.encode(key, params, hookData));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        (PoolKey memory key, SwapParams memory params, bytes memory hookData) =
            abi.decode(data, (PoolKey, SwapParams, bytes));

        BalanceDelta delta = poolManager.swap(key, params, hookData);

        console2.log("Swap delta amount0:", int256(delta.amount0()));
        console2.log("Swap delta amount1:", int256(delta.amount1()));

        if (delta.amount0() < 0) {
            poolManager.sync(key.currency0);
            IERC20(Currency.unwrap(key.currency0)).transfer(address(poolManager), uint256(uint128(-delta.amount0())));
            poolManager.settle();
        }
        if (delta.amount1() < 0) {
            poolManager.sync(key.currency1);
            IERC20(Currency.unwrap(key.currency1)).transfer(address(poolManager), uint256(uint128(-delta.amount1())));
            poolManager.settle();
        }

        if (delta.amount0() > 0) {
            poolManager.take(key.currency0, address(this), uint256(uint128(delta.amount0())));
        }
        if (delta.amount1() > 0) {
            poolManager.take(key.currency1, address(this), uint256(uint128(delta.amount1())));
        }

        return abi.encode(delta);
    }
}

contract ExecuteSwap is Script {
    function run() external {
        address poolManagerAddr = vm.envAddress("POOL_MANAGER_TESTNET");
        address hookAddress = vm.envAddress("HOOK_ADDRESS_TESTNET");
        address token0 = vm.envAddress("TOKEN0_TESTNET");
        address token1 = vm.envAddress("TOKEN1_TESTNET");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        require(poolManagerAddr != address(0), "Set POOL_MANAGER_TESTNET in .env");
        require(hookAddress != address(0), "Set HOOK_ADDRESS_TESTNET in .env");
        require(token0 != address(0), "Set TOKEN0_TESTNET in .env");
        require(token1 != address(0), "Set TOKEN1_TESTNET in .env");

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 0x800000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });

        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -0.01 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        bytes memory hookData = abi.encode(deployer);

        vm.startBroadcast();

        SwapHelper helper = new SwapHelper(IPoolManager(poolManagerAddr));

        uint256 swapAmount = 1 ether;
        IERC20(token0).transfer(address(helper), swapAmount);
        IERC20(token1).transfer(address(helper), swapAmount);

        helper.executeSwap(key, params, hookData);

        console2.log("Swap executed with hookData for:", deployer);

        vm.stopBroadcast();
    }
}
