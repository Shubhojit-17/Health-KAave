// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import {EasyPosm} from "./utils/libraries/EasyPosm.sol";

import {AaveHealthHook} from "../src/AaveHealthHook.sol";
import {BaseTest} from "./utils/BaseTest.sol";

contract MockAavePool {
    mapping(address => uint256) public healthFactors;
    mapping(address => uint256) public debts;

    function setUserData(address user, uint256 healthFactor, uint256 debt) external {
        healthFactors[user] = healthFactor;
        debts[user] = debt;
    }

    function getUserAccountData(address user)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        return (1000e8, debts[user], 500e8, 8000, 7500, healthFactors[user]);
    }
}

contract AaveHealthHookTest is BaseTest {
    using EasyPosm for IPositionManager;
    using CurrencyLibrary for Currency;

    AaveHealthHook hook;
    MockAavePool mockAave;
    PoolKey poolKey;

    address STRONG_USER = address(0x1111);
    address MODERATE_USER = address(0x2222);
    address DANGER_USER = address(0x3333);
    address NO_DEBT_USER = address(0x4444);

    Currency currency0;
    Currency currency1;
    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    function setUp() public {
        deployArtifactsAndLabel();

        (currency0, currency1) = deployCurrencyPair();

        mockAave = new MockAavePool();

        mockAave.setUserData(STRONG_USER, 3e18, 100e8);
        mockAave.setUserData(MODERATE_USER, 1_7e17, 100e8);
        mockAave.setUserData(DANGER_USER, 1_2e17, 100e8);
        mockAave.setUserData(NO_DEBT_USER, type(uint256).max, 0);

        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);

        bytes memory constructorArgs = abi.encode(address(poolManager), address(mockAave));

        (address hookAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, type(AaveHealthHook).creationCode, constructorArgs);

        hook = new AaveHealthHook{salt: salt}(poolManager, address(mockAave));
        require(address(hook) == hookAddress, "Hook address mismatch");

        poolKey = PoolKey(currency0, currency1, 0x800000, 60, IHooks(hook));
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);

        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        (tokenId,) = positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            Constants.ZERO_BYTES
        );
    }

    function test_StrongUser_GetsDiscountedFee() public view {
        (uint24 fee, uint256 hf) = hook.previewFee(STRONG_USER);
        assertEq(fee, hook.DISCOUNTED_FEE(), "Strong user should get discounted fee");
        assertGe(hf, hook.HF_STRONG(), "Health factor should be above strong threshold");
    }

    function test_ModerateUser_GetsStandardFee() public view {
        (uint24 fee,) = hook.previewFee(MODERATE_USER);
        assertEq(fee, hook.STANDARD_FEE(), "Moderate user should get standard fee");
    }

    function test_DangerUser_GetsPremiumFee() public view {
        (uint24 fee,) = hook.previewFee(DANGER_USER);
        assertEq(fee, hook.PREMIUM_FEE(), "Danger user should get premium fee");
    }

    function test_NoDebtUser_GetsStandardFee() public view {
        (uint24 fee,) = hook.previewFee(NO_DEBT_USER);
        assertEq(fee, hook.STANDARD_FEE(), "No-debt user should get standard fee");
    }

    function test_EmptyHookData_FallsBackToStandard() public {
        swapRouter.swapExactTokensForTokens({
            amountIn: 1e18,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });
    }

    function test_SwapWithHookData_Works() public {
        bytes memory hookData = abi.encode(STRONG_USER);

        swapRouter.swapExactTokensForTokens({
            amountIn: 1e18,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: hookData,
            receiver: address(this),
            deadline: block.timestamp + 1
        });
    }

    function test_MsgSender_IsNotUser() public {
        mockAave.setUserData(address(poolManager), 5e18, 100e8);

        (uint24 fee,) = hook.previewFee(DANGER_USER);
        assertEq(fee, hook.PREMIUM_FEE(), "Must use hookData address, not msg.sender");
    }
}
