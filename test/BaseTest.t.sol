// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title BaseTest.t
 * @author Yabes Theodorus
 * @notice Short description of contract
 * @dev Created 2025
 */

import {Test, console} from "forge-std/Test.sol";
import {DeployEtherBeast} from "script/DeployEtherBeast.s.sol";

import {EtherBeastToken} from "src/EtherBeastToken.sol";
import {EtherBeastGatcha} from "src/EtherBeastGatcha.sol";
import {EtherBeastNFT} from "src/EtherBeastNFT.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract BaseTest is Test {
    EtherBeastToken token;
    EtherBeastGatcha gatcha;
    EtherBeastNFT nft;

    HelperConfig config;
    address USER = makeAddr("user");

    function setUp() public {
        DeployEtherBeast deploy = new DeployEtherBeast();
        (token, nft, gatcha, config) = deploy.run();
    }
}
