// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// forge script --chain 11155420 script/DeployForestContracts.sol:DeployScript --rpc-url $OP_SEPOLIA_RPC_URL --broadcast --verify --etherscan-api-key $OP_SEPOLIA_API_KEY -vvvv --with-gas-price
// forge script script/DeployForestContracts.sol:DeployScript --rpc-url 127.0.0.1:8545 --broadcast

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import "../src/ForestCommon.sol";
import {ForestRegistry} from "../src/ForestRegistry.sol";
import {ForestSlasher} from "../src/ForestSlasher.sol";
import {ForestToken} from "../src/ForestToken.sol";
import {Script, console2} from "forge-std/Script.sol";

contract DeployScript is Script {
    uint256 runOn = vm.envUint("RUN_ON");
    uint256 privKey;
    address keyAddr;
    address tokenAddr;

    ForestRegistry public registry;
    ForestSlasher public slasher;
    ForestToken public forestContract;

    uint public PARAM_REVENUE_SHARE = 1000; //10.00%
    uint public PARAM_MAX_PCS_NUM = 10;
    uint public PARAM_ACTOR_REG_FEE = 1 ether;
    uint public PARAM_PC_REG_FEE = 1000 ether;
    uint public PARAM_ACTOR_IN_PC_REG_FEE = 1 ether;
    uint public PARAM_OFFER_IN_PC_REG_FEE = 1 ether;
    uint public PARAM_BURN_RATIO = 2000; // 20.00%

    function setUp() public {
    }

    function run() public {
        if (runOn == 0) {
            // 0 - local
            privKey = vm.envUint("LOCAL_PRIV_KEY");
            keyAddr = vm.addr(privKey);
            tokenAddr = vm.envAddress("LOCAL_TOKEN_ADDRESS");
        } else if (runOn == 1) {
            // 1 - op sepolia
            privKey = vm.envUint("OP_SEPOLIA_PRIV_KEY");
            keyAddr = vm.addr(privKey);
            tokenAddr = vm.envAddress("OP_SEPOLIA_USDC_TOKEN_ADDRESS");
        } else if (runOn == 2) {
            // 2 - op mainnet
            privKey = vm.envUint("OP_MAINNET_PRIV_KEY");
            keyAddr = vm.addr(privKey);
            tokenAddr = vm.envAddress("OP_MAINNET_USDC_TOKEN_ADDRESS");
        } else {
            revert("Invalid runOn value");
        }

        address PARAM_TREASURY_ADDR = keyAddr;

        console2.log("Account address: ", keyAddr);
        console2.log("Balance of deployer: ", keyAddr.balance);

        vm.startBroadcast(privKey);
        forestContract = new ForestToken();
        slasher = new ForestSlasher();
        registry = new ForestRegistry(address(slasher), tokenAddr, address(forestContract), PARAM_REVENUE_SHARE, PARAM_MAX_PCS_NUM, PARAM_ACTOR_REG_FEE, PARAM_PC_REG_FEE, PARAM_ACTOR_IN_PC_REG_FEE, PARAM_OFFER_IN_PC_REG_FEE, PARAM_TREASURY_ADDR, PARAM_BURN_RATIO);
        slasher.setRegistryAndForestAddr(address(registry));
        forestContract.setRegistryAndSlasherAddr(address(registry));
        vm.stopBroadcast();
    }
}
