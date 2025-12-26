// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title DeployEtherBeast
 * @author Yabes Theodorus
 * @notice Short description of contract
 * @dev Created 2025
 */

import {HelperConfig} from "script/HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";

import {EtherBeastToken} from "src/EtherBeastToken.sol";
import {EtherBeastGatcha} from "src/EtherBeastGatcha.sol";
import {EtherBeastNFT} from "src/EtherBeastNFT.sol";
import {EtherBeastTypes} from "src/EtherBeastTypes.sol";

import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interaction.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract DeployEtherBeast is Script {
    HelperConfig config;
    EtherBeastToken token;
    EtherBeastGatcha gatcha;
    EtherBeastNFT nft;

    function run() public returns (EtherBeastToken, EtherBeastNFT, EtherBeastGatcha, HelperConfig) {
        config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();

        if (networkConfig.subsId == 0) {
            // creating subscription
            CreateSubscription createSub = new CreateSubscription();
            (networkConfig.subsId, networkConfig.vrfCoordinatorAddress) =
                createSub.createSubscription(networkConfig.vrfCoordinatorAddress, networkConfig.account);
            // funding subscription
            FundSubscription fundSubs = new FundSubscription();
            fundSubs.fundSubscription(
                networkConfig.vrfCoordinatorAddress,
                networkConfig.subsId,
                networkConfig.linkToken,
                networkConfig.account
            );
        }

        (uint8[] memory beastIds, uint8[] memory beastElements, string[] memory imageURI) = predefineBeasts();

        vm.startBroadcast();
        token = new EtherBeastToken(networkConfig.priceFeedAddress);
        nft = new EtherBeastNFT();
        gatcha = new EtherBeastGatcha(
            payable(address(token)),
            address(nft),
            beastIds,
            beastElements,
            imageURI,
            networkConfig.vrfCoordinatorAddress,
            networkConfig.keyHash,
            networkConfig.subsId
        );
        nft.setGatchaContract(address(gatcha));
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(gatcha), networkConfig.vrfCoordinatorAddress, networkConfig.subsId, networkConfig.account
        );

        return (token, nft, gatcha, config);
    }

    function predefineBeasts()
        public
        pure
        returns (uint8[] memory beastIds, uint8[] memory beastElements, string[] memory imageURI)
    {
        beastIds = new uint8[](4);
        beastElements = new uint8[](4);
        imageURI = new string[](4);

        beastIds[0] = 50;
        beastIds[1] = 63;
        beastIds[2] = 38;
        beastIds[3] = 74;

        beastElements[0] = uint8(EtherBeastTypes.EtherBeastElement.Fire);
        beastElements[1] = uint8(EtherBeastTypes.EtherBeastElement.Ice);
        beastElements[2] = uint8(EtherBeastTypes.EtherBeastElement.Nature);
        beastElements[3] = uint8(EtherBeastTypes.EtherBeastElement.Thunder);

        imageURI[0] = "";
        imageURI[1] = "";
        imageURI[2] = "";
        imageURI[3] = "";
    }
}
