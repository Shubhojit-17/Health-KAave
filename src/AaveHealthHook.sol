// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager, SwapParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";

contract AaveHealthHook is BaseHook {
    uint256 public constant HF_STRONG = 2e18;
    uint256 public constant HF_MODERATE = 1_500000000000000000;
    uint256 public constant HF_DANGER = 1e18;

    uint24 public constant DISCOUNTED_FEE = 100;
    uint24 public constant STANDARD_FEE = 3000;
    uint24 public constant PREMIUM_FEE = 5000;

    IAavePool public immutable aavePool;

    event FeeApplied(address indexed user, uint256 healthFactor, uint24 feeApplied);

    constructor(IPoolManager _poolManager, address _aavePool) BaseHook(_poolManager) {
        require(_aavePool != address(0), "AaveHealthHook: zero aave pool address");
        aavePool = IAavePool(_aavePool);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _beforeSwap(
        address,
        PoolKey calldata,
        SwapParams calldata,
        bytes calldata hookData
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        uint24 fee = STANDARD_FEE;

        if (hookData.length >= 32) {
            address user = abi.decode(hookData, (address));

            if (user != address(0)) {
                uint24 computedFee = _getFeeForUser(user);
                fee = computedFee;
            }
        }

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee);
    }

    function _getFeeForUser(address user) internal returns (uint24) {
        if (address(aavePool).code.length == 0) {
            emit FeeApplied(user, 0, STANDARD_FEE);
            return STANDARD_FEE;
        }

        try aavePool.getUserAccountData(user) returns (
            uint256,
            uint256 totalDebtBase,
            uint256,
            uint256,
            uint256,
            uint256 healthFactor
        ) {
            if (totalDebtBase == 0) {
                emit FeeApplied(user, healthFactor, STANDARD_FEE);
                return STANDARD_FEE;
            }

            uint24 fee;
            if (healthFactor >= HF_STRONG) {
                fee = DISCOUNTED_FEE;
            } else if (healthFactor >= HF_MODERATE) {
                fee = STANDARD_FEE;
            } else {
                fee = PREMIUM_FEE;
            }

            emit FeeApplied(user, healthFactor, fee);
            return fee;
        } catch {
            emit FeeApplied(user, 0, STANDARD_FEE);
            return STANDARD_FEE;
        }
    }

    function previewFee(address user) external view returns (uint24 fee, uint256 healthFactor) {
        (, uint256 totalDebtBase, , , , uint256 hf) = aavePool.getUserAccountData(user);

        if (totalDebtBase == 0) return (STANDARD_FEE, hf);

        if (hf >= HF_STRONG) return (DISCOUNTED_FEE, hf);
        if (hf >= HF_MODERATE) return (STANDARD_FEE, hf);
        return (PREMIUM_FEE, hf);
    }
}
