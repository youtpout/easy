//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../contracts/Invest.sol";
import "./DeployHelpers.s.sol";

contract DeployScript is ScaffoldETHDeploy {
    error InvalidPrivateKey(string);

    function run() external {
        uint256 deployerPrivateKey = setupLocalhostEnv();
        if (deployerPrivateKey == 0) {
            revert InvalidPrivateKey(
                "You don't have a deployer account. Make sure you have set DEPLOYER_PRIVATE_KEY in .env or use `yarn generate` to generate a new random account"
            );
        }
        vm.startBroadcast(deployerPrivateKey);

        Invest yourContract = new Invest(
            vm.addr(deployerPrivateKey),
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,
            0xC36442b4a4522E871399CD717aBDD847Ab11FE88,
            100
        );
        console.logString(
            string.concat(
                "YourContract deployed at: ",
                vm.toString(address(yourContract))
            )
        );

        vm.stopBroadcast();

        /**
         * This function generates the file containing the contracts Abi definitions.
         * These definitions are used to derive the types needed in the custom scaffold-eth hooks, for example.
         * This function should be called last.
         */
        exportDeployments();
    }

    function test() public {}
}
