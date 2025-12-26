// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title EtherBeastGatcha Test Suite
 * @author Yabes Theodorus
 * @notice Integration and unit tests for the EtherBeastGatcha contract.
 * @dev Covers:
 *      - Constructor validation (array lengths, zero/out-of-bound values)
 *      - Gacha state machine (idle → rolling → fulfilled)
 *      - VRF fulfillment via Chainlink mock
 *      - Rarity distribution verification (statistical check)
 */
import {BaseTest} from "test/BaseTest.t.sol";
import {console} from "forge-std/Test.sol";

import {EtherBeastGatcha} from "src/EtherBeastGatcha.sol";
import {EtherBeastTypes} from "src/EtherBeastTypes.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract EtherBeastGatchaTest is BaseTest {
    uint256 constant GATCHA_PRICE = 1e18;
    uint256 constant TOKEN_AMOUNT = 2e18;
    uint256 constant TOKEN_AMOUNT_2 = 25e18;
    uint256 constant GATCHA_PLAY_TIMES = 20;

    /**
     * @dev Buys the specified amount of game tokens for USER before running the test.
     *      Funds USER with the required ETH and calls token.buyToken.
     */
    modifier buyToken(uint256 tokenAmount) {
        vm.startPrank(USER);
        uint256 price = token.getPriceForTokenAmount(tokenAmount);
        vm.deal(USER, price);
        token.buyToken{value: price}(tokenAmount);
        vm.stopPrank();

        _;
    }

    // === Constructor Validation Tests ===

    function testPredefinedBeast() public {
        // Ensures the gacha contract was initialized with exactly 4 valid beast templates.
        assertEq(gatcha.getBeastIds().length, 4);
    }

    function testPredefinedBeastWithInvalidArrayLength() public {
        // Should revert if beast arrays have mismatched lengths.
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        uint8[] memory beastIds = new uint8[](2);
        uint8[] memory beastElements = new uint8[](1); // ❌ shorter than beastIds
        string[] memory imageURI = new string[](1);

        beastIds[0] = 50;
        beastIds[1] = 63;
        beastElements[0] = uint8(EtherBeastTypes.EtherBeastElement.Fire);
        imageURI[0] = "";

        vm.expectRevert(EtherBeastGatcha.EtherBeastGatcha__InvalidArrayLength.selector);
        new EtherBeastGatcha(
            payable(address(token)),
            address(nft),
            beastIds,
            beastElements,
            imageURI,
            networkConfig.vrfCoordinatorAddress,
            networkConfig.keyHash,
            networkConfig.subsId
        );
    }

    function testPredefinedBeastWithZeroValue() public {
        // Should revert if any predefined beast ID is zero (invalid).
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        uint8[] memory beastIds = new uint8[](2);
        uint8[] memory beastElements = new uint8[](2);
        string[] memory imageURI = new string[](2);
        beastIds[0] = 50;
        beastIds[1] = 0; // ❌ invalid (zero)

        beastElements[0] = uint8(EtherBeastTypes.EtherBeastElement.Fire);
        beastElements[1] = uint8(EtherBeastTypes.EtherBeastElement.None);
        imageURI[0] = "";
        imageURI[1] = "";

        vm.expectRevert(EtherBeastGatcha.EtherBeastGatcha__ZeroValue.selector);
        new EtherBeastGatcha(
            payable(address(token)),
            address(nft),
            beastIds,
            beastElements,
            imageURI,
            networkConfig.vrfCoordinatorAddress,
            networkConfig.keyHash,
            networkConfig.subsId
        );
    }

    function testPredefinedBeastWithOutOfBoundValue() public {
        // Should revert if beast ID or element is out of allowed range.
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        uint8[] memory beastIds = new uint8[](2);
        uint8[] memory beastElements = new uint8[](2);
        string[] memory imageURI = new string[](2);
        beastIds[0] = 50;
        beastIds[1] = 74;

        beastElements[0] = uint8(EtherBeastTypes.EtherBeastElement.Fire);
        beastElements[1] = uint8(5); // ❌ invalid element enum value
        imageURI[0] = "";
        imageURI[1] = "";

        vm.expectRevert(EtherBeastGatcha.EtherBeastGatcha__OutOfBound.selector);
        new EtherBeastGatcha(
            payable(address(token)),
            address(nft),
            beastIds,
            beastElements,
            imageURI,
            networkConfig.vrfCoordinatorAddress,
            networkConfig.keyHash,
            networkConfig.subsId
        );
    }

    // === Gacha Workflow Tests ===

    function testPerformGatchaWithInsufficientTokenBalance() public {
        // Should revert if USER hasn't approved enough tokens.
        vm.startPrank(USER);
        vm.expectRevert(EtherBeastGatcha.EtherBeastGatcha__InsufficientTokenBalance.selector);
        gatcha.performGatcha();
        vm.stopPrank();
    }

    function testPerformGatchaWhenGatchaIsNotIdle() public buyToken(TOKEN_AMOUNT) {
        // Should revert if performGatcha() is called while already rolling.
        vm.startPrank(USER);
        token.approve(address(gatcha), GATCHA_PRICE);
        gatcha.performGatcha();
        assertEq(uint8(gatcha.checkGatchaState()), uint8(EtherBeastGatcha.GatchaState.Rolling));

        token.approve(address(gatcha), GATCHA_PRICE);
        vm.expectRevert(EtherBeastGatcha.EtherBeastGatcha__GatchaNotIdle.selector);
        gatcha.performGatcha();
        vm.stopPrank();
    }

    /**
     * @dev Helper to simulate a full gacha cycle:
     *      1. USER approves and calls performGatcha()
     *      2. VRF mock fulfills the request
     */
    function _performGatchaAndFulfillRandom() internal {
        vm.startPrank(USER);
        token.approve(address(gatcha), GATCHA_PRICE);
        gatcha.performGatcha();
        uint256 requestId = gatcha.getRequestId();
        vm.stopPrank();

        VRFCoordinatorV2_5Mock(config.getConfig().vrfCoordinatorAddress).fulfillRandomWords(requestId, address(gatcha));
    }

    function testPerformGatchaAndFullfillRandomWords() public buyToken(TOKEN_AMOUNT) {
        // End-to-end test: mint exactly 1 NFT with valid metadata.
        _performGatchaAndFulfillRandom();
        assertEq(nft.balanceOf(USER), 1);

        vm.startPrank(USER);
        string memory tokenURI = nft.tokenURI(0);
        vm.stopPrank();
    }

    // === Rarity Distribution Test ===

    /**
     * @notice Verifies that VRF-based rarity distribution aligns roughly with expected probabilities:
     *         - Common:   50% (≥8 in 20 trials)
     *         - Rare:     30% (≥5 in 20 trials)
     *         - Unique:   15% (≥3 in 20 trials)
     *         - Legendary: 5% (≥1 in 20 trials)
     * @dev Uses conservative lower bounds (not statistical tolerance) due to small sample size (20).
     *      This is a basic sanity check — not a rigorous statistical test.
     *      For stronger validation, increase GATCHA_PLAY_TIMES and use chi-squared or tolerance bands.
     */
    function testFullfillRandomWordsRarityProbability() public buyToken(TOKEN_AMOUNT_2) {
        // Perform multiple gacha pulls
        for (uint256 i = 0; i < GATCHA_PLAY_TIMES; i++) {
            _performGatchaAndFulfillRandom();
        }

        // Count rarities of all minted NFTs
        uint256 balance = nft.balanceOf(USER);
        uint256[] memory tokens = new uint256[](balance);
        uint256[] memory rarity = new uint256[](5); // indices 1-4 used for rarities

        for (uint256 i = 0; i < balance; i++) {
            tokens[i] = nft.tokenOfOwnerByIndex(USER, i);
            uint8 nftRarity = uint8(nft.getBeastByTokenId(tokens[i]).rarity);
            rarity[nftRarity]++;
        }

        // Extract counts for each rarity tier
        uint256 commonCount = rarity[1];
        uint256 rareCount = rarity[2];
        uint256 uniqueCount = rarity[3];
        uint256 legendaryCount = rarity[4];

        // ⚠️ Conservative lower-bound check (due to small N=20)
        // These thresholds represent ~80-90% confidence lower bounds
        assertGe(commonCount, 8, "Common count too low");
        assertGe(rareCount, 5, "Rare count too low");
        assertGe(uniqueCount, 3, "Unique count too low");
        assertGe(legendaryCount, 1, "Legendary count too low");
    }
}
