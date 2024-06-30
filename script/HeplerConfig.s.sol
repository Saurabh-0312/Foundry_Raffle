//SPDX-Licence_Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entrancefee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gaslane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }

    uint256 public constant DEFAULT_ANVIL_KEY =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    NetworkConfig public activenetworkconfig;

    constructor() {
        if (block.chainid == 11155111) {
            activenetworkconfig = getSepoliaEthConfig();
        } else {
            activenetworkconfig = getAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entrancefee: 0.01 ether,
                interval: 30,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                gaslane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 11971, // update with subId
                callbackGasLimit: 500000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activenetworkconfig.vrfCoordinator != address(0)) {
            return activenetworkconfig;
        }
        uint96 baseFee = 0.25 ether;
        uint96 gasPrice = 1e9;

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPrice
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return
            NetworkConfig({
                entrancefee: 0.01 ether,
                interval: 30,
                vrfCoordinator: address(vrfCoordinatorV2Mock),
                gaslane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0, // our script will add this
                callbackGasLimit: 500000,
                link: address(link),
                deployerKey: DEFAULT_ANVIL_KEY
            });
    }
}
