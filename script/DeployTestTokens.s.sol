// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract DeployTestTokens is Script {
    function run() external {
        vm.startBroadcast();

        TestToken tokenA = new TestToken("Test WETH", "tWETH");
        TestToken tokenB = new TestToken("Test USDT", "tUSDT");

        console2.log("tWETH deployed at:", address(tokenA));
        console2.log("tUSDT deployed at:", address(tokenB));

        if (address(tokenA) < address(tokenB)) {
            console2.log("TOKEN0 (smaller):", address(tokenA));
            console2.log("TOKEN1 (larger):", address(tokenB));
        } else {
            console2.log("TOKEN0 (smaller):", address(tokenB));
            console2.log("TOKEN1 (larger):", address(tokenA));
        }

        vm.stopBroadcast();
    }
}
