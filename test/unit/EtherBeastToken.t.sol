// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title EtherBeastTokenTest
 * @author Yabes
 * @notice Test suite for EtherBeastToken
 *
 * @dev
 * Covers:
 *    - Price calculation from USD-based oracle
 *    - Buying tokens with exact ETH
 *    - Reverts on underpayment
 *    - ETH refund on overpayment
 *    - Oracle invalid price handling
 *    - Reverting on direct ETH transfer (receive / fallback)
 *
 * Assumptions:
 *    - Mock price feed is initialized to 2000 USD / ETH (8 decimals)
 *    - Minimum token top-up is 1e18 (1 token)
 */

import {BaseTest} from "test/BaseTest.t.sol";
import {EtherBeastToken} from "src/EtherBeastToken.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract EtherBeastTokenTest is BaseTest {
    /**
     * @notice Verifies token price calculation and input validation
     *
     * @dev
     * - Bounds tokenAmount between 1 and 1000 tokens (1e18 precision)
     * - With ETH/USD = 2000e8, 1 token costs 0.0005 ETH (5e14 wei)
     * - Ensures:
     *   - Correct price calculation
     *   - Revert on zero token amount
     *   - Revert on amount below minimum top-up
     */
    function testGetPriceForTokenAmount(uint256 tokenAmount) public {
        tokenAmount = bound(tokenAmount, 1e18, 1000e18);
        // Mock price is 2000e8 usd / eth
        // so price per 1e18 token is 0,0005 (5e14)
        uint256 price = token.getPriceForTokenAmount(tokenAmount);
        uint256 expectedPrice = (tokenAmount * 5e14) / 1e18;

        assertEq(price, expectedPrice);

        //Test amount 0
        tokenAmount = 0;
        vm.expectRevert(EtherBeastToken.EtherBeastToken__ZeroValue.selector);
        uint256 priceZero = token.getPriceForTokenAmount(tokenAmount);

        //Test amount below minimum
        tokenAmount = 5e10;
        vm.expectRevert(EtherBeastToken.EtherBeastToken__BelowMinimumTopUp.selector);
        uint256 priceBelow = token.getPriceForTokenAmount(tokenAmount);
    }

    /**
     * @notice Tests successful token purchase with exact ETH value
     *
     * @dev
     *    - USER sends exactly the required ETH
     *    - Token balance should increase by tokenAmount
     *    - No ETH refund expected
     */

    function testBuyToken(uint256 tokenAmount) public {
        tokenAmount = bound(tokenAmount, 1e18, 1000e18);

        vm.startPrank(USER);
        uint256 price = token.getPriceForTokenAmount(tokenAmount);
        vm.deal(USER, price);
        token.buyToken{value: price}(tokenAmount);
        vm.stopPrank();

        assertEq(token.balanceOf(USER), tokenAmount);
    }

    /**
     * @notice Ensures buyToken reverts when ETH sent is insufficient
     *
     * @dev
     * - USER sends (price - 1 wei)
     * - Must revert with EtherBeastToken__SendMoreToBuyToken
     */

    function testBuyTokenWithLessValueToSend(uint256 tokenAmount) public {
        tokenAmount = bound(tokenAmount, 1e18, 1000e18);

        // Test failed branches : Send value below price
        vm.startPrank(USER);
        uint256 price = token.getPriceForTokenAmount(tokenAmount);
        vm.deal(USER, price);
        vm.expectRevert(EtherBeastToken.EtherBeastToken__SendMoreToBuyToken.selector);
        token.buyToken{value: price - 1}(tokenAmount);
        vm.stopPrank();
    }

    /**
     * @notice Ensures excess ETH is refunded after token purchase
     *
     * @dev
     * - USER sends more ETH than required
     * - Contract should:
     *   - Mint tokens
     *   - Refund the extra ETH
     * - Final USER ETH balance should equal refundValue
     */

    function testBuyTokenWithRefund(uint256 tokenAmount) public {
        tokenAmount = bound(tokenAmount, 1e18, 1000e18);

        uint256 refundValue = 1e14;

        vm.startPrank(USER);
        uint256 price = token.getPriceForTokenAmount(tokenAmount);
        vm.deal(USER, price + refundValue);
        token.buyToken{value: price + refundValue}(tokenAmount);
        vm.stopPrank();

        assertEq(token.balanceOf(USER), tokenAmount);

        assertEq(USER.balance, refundValue);
    }

    /**
     * @notice Verifies behavior when oracle returns an invalid price
     *
     * @dev
     * - Mocks price feed to return 0
     * - getPriceForTokenAmount must revert
     * - Protects against broken or malicious oracle data
     */

    function testInvalidPrice() public {
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();

        MockV3Aggregator(networkConfig.priceFeedAddress).updateAnswer(0);
        vm.expectRevert(EtherBeastToken.EtherBeastToken__InvalidPrice.selector);

        uint256 price = token.getPriceForTokenAmount(1e18);
    }

    /**
     * @notice Ensures direct ETH transfers to the token contract are rejected
     *
     * @dev
     * - Sending ETH via receive / fallback should revert
     * - Forces users to go through buyToken()
     * - Prevents accidental ETH loss
     */

    function testReceiveFallbackWillRevert() public {
        vm.startPrank(USER);
        vm.deal(USER, 1e18);
        vm.expectRevert(EtherBeastToken.EtherBeastToken__DirectEthNotAllowed.selector);
        (bool success,) = address(token).call{value: 1e18}("");

        vm.stopPrank();
    }
}
