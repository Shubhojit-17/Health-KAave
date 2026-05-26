// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquidityHelper is IUnlockCallback {
    IPoolManager public immutable poolManager;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    function addLiquidity(
        PoolKey memory key,
        int24 tickLower,
        int24 tickUpper,
        int256 liquidityDelta,
        bytes memory hookData
    ) external {
        IERC20(Currency.unwrap(key.currency0)).approve(address(poolManager), type(uint256).max);
        IERC20(Currency.unwrap(key.currency1)).approve(address(poolManager), type(uint256).max);

        poolManager.unlock(abi.encode(key, tickLower, tickUpper, liquidityDelta, hookData));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        (PoolKey memory key, int24 tickLower, int24 tickUpper, int256 liquidityDelta, bytes memory hookData) =
            abi.decode(data, (PoolKey, int24, int24, int256, bytes));

        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidityDelta,
            salt: bytes32(0)
        });

        (BalanceDelta delta,) = poolManager.modifyLiquidity(key, params, hookData);

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

        return abi.encode(delta);
    }
}

contract InitializePool is Script {
    function run() external {
        address poolManagerAddr = vm.envAddress("POOL_MANAGER_TESTNET");
        address hookAddress = vm.envAddress("HOOK_ADDRESS_TESTNET");
        address token0 = vm.envAddress("TOKEN0_TESTNET");
        address token1 = vm.envAddress("TOKEN1_TESTNET");

        require(poolManagerAddr != address(0), "Set POOL_MANAGER_TESTNET in .env");
        require(hookAddress != address(0), "Set HOOK_ADDRESS_TESTNET in .env");
        require(token0 != address(0), "Set TOKEN0_TESTNET in .env");
        require(token1 != address(0), "Set TOKEN1_TESTNET in .env");
        require(token0 < token1, "TOKEN0 must be numerically less than TOKEN1");

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 0x800000,
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });

        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0);

        vm.startBroadcast();

        IPoolManager(poolManagerAddr).initialize(key, sqrtPriceX96);
        console2.log("Pool initialized successfully");

        LiquidityHelper helper = new LiquidityHelper(IPoolManager(poolManagerAddr));

        uint256 tokenAmount = 100 ether;
        IERC20(token0).transfer(address(helper), tokenAmount);
        IERC20(token1).transfer(address(helper), tokenAmount);

        int24 tickLower = -6000;
        int24 tickUpper = 6000;
        int256 liquidityDelta = 10 ether;

        helper.addLiquidity(key, tickLower, tickUpper, liquidityDelta, new bytes(0));
        console2.log("Liquidity added successfully");

        vm.stopBroadcast();
    }
}
