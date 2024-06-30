//SPDX-Licence_Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "../script/HeplerConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsmer} from "../script/interaction.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperconfig = new HelperConfig();
        (
            uint256 entrancefee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gaslane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint256 deployerKey
        ) = helperconfig.activenetworkconfig();

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();

            subscriptionId = createSubscription.createSubscription(
                vrfCoordinator,
                deployerKey
            );

            // fund subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subscriptionId,
                link,
                deployerKey
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entrancefee,
            interval,
            vrfCoordinator,
            gaslane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsmer addConsumer = new AddConsmer();
        addConsumer.addconsumer(
            address(raffle),
            vrfCoordinator,
            subscriptionId,
            deployerKey
        );
        return (raffle, helperconfig);
    }
}
