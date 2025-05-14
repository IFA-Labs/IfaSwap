//SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IfaSwapFactory} from "../src/IfaSwapFactory.sol";
import {IfaSwapRouter} from "src/IfaSwapRouter.sol";
import {MockWETH} from "../test/integration.sol";

contract DeploySwap is Script {
    IfaSwapFactory ifaSwapFactory;
    IfaSwapRouter ifaSwapRouter;
    MockWETH weth;

    bytes32 constant SALT_IfaSwapFactory = keccak256("IfaSwapFactory");
    bytes32 constant SALT_IfaSwapRouter = keccak256("IfaSwapRouter");
    bytes32 constant SALT_weth = keccak256("weth");

    function run() public {
        vm.startBroadcast();
        console.log("Deploying from:", msg.sender);
        address owner = msg.sender;
        _depolySwap(owner);

        vm.stopBroadcast();
    }

    function _depolySwap(address owner) internal {
        weth = new MockWETH{salt: SALT_weth}();
        ifaSwapFactory = new IfaSwapFactory{salt: SALT_IfaSwapFactory}(
            owner, owner, address(0xbF2ae81D8Adf3AA22401C4cC4f0116E936e1025b)
        );
        console.log("ifaSwapFactory deployed at:", address(ifaSwapFactory));

        ifaSwapRouter = new IfaSwapRouter{salt: SALT_IfaSwapRouter}(
            address(ifaSwapFactory), address(weth), address(0xbF2ae81D8Adf3AA22401C4cC4f0116E936e1025b)
        ); //@note change the address when deploying to testnet/mainnet
        console.log("IfaSwapRouter deployed at:", address(ifaSwapRouter));
    }
}
