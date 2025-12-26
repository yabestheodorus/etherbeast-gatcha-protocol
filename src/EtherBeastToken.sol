// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title EtherBeastToken
 * @author Yabes Theodorus
 * @notice ERC20 utility token priced at a fixed USD value and purchasable with ETH.
 *
 * @dev
 * EtherBeastToken represents an in-protocol currency used within the EtherBeast ecosystem.
 * Tokens are sold at a fixed unit price of 1 USD per token, while payments are made in ETH.
 *
 * The ETH/USD conversion rate is obtained from a Chainlink price feed.
 * All calculations are performed using 18-decimal fixed-point arithmetic
 * to ensure precision and avoid integer truncation.
 *
 * Key properties:
 * - 1 token == 1 USD (unit of account)
 * - ETH amount required adjusts dynamically based on market price
 * - Supports exact payment and refunds excess ETH
 * - Uses custom errors for gas efficiency
 *
 * This contract does NOT attempt to stabilize token value on secondary markets.
 * Price stability applies only at the point of minting.
 */

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract EtherBeastToken is ERC20, ERC20Burnable {
    /*////////////////////////////////////////////////////////////////////////////
                                          ERRORS
    ///////////////////////////////////////////////////////////////////////////*/

    error EtherBeastToken__ZeroValue();
    error EtherBeastToken__SendMoreToBuyToken();
    error EtherBeastToken__InvalidPrice();
    error EtherBeastToken__TransferFailed();
    error EtherBeastToken__DirectEthNotAllowed();
    error EtherBeastToken__BelowMinimumTopUp();

    /*////////////////////////////////////////////////////////////////////////////
                                    STATE VARIABLES
    ///////////////////////////////////////////////////////////////////////////*/

    address private immutable i_priceFeedAddress;
    uint256 private constant TOKEN_DECIMALS = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant PRICE_FEED_PRECISION_PADDING = 1e10;

    /*////////////////////////////////////////////////////////////////////////////
                                          EVENTS
    ///////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a user successfully purchases tokens.
     * @param user Address that purchased the tokens.
     * @param tokenAmount Amount of tokens minted (18 decimals).
     */
    event TokenPurchased(address indexed user, uint256 tokenAmount);

    /*////////////////////////////////////////////////////////////////////////////
                                        CONSTRUCTOR
    ///////////////////////////////////////////////////////////////////////////*/

    constructor(address priceFeedAddress) ERC20("EtherBeast Token", "ETB") {
        i_priceFeedAddress = priceFeedAddress;
    }

    /*////////////////////////////////////////////////////////////////////////////
                                   RECEIVE / FALLBACK
    ///////////////////////////////////////////////////////////////////////////*/

    receive() external payable {
        revert EtherBeastToken__DirectEthNotAllowed();
    }

    fallback() external payable {
        revert EtherBeastToken__DirectEthNotAllowed();
    }

    /*////////////////////////////////////////////////////////////////////////////
                               PUBLIC / EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the required ETH amount to purchase a given number of tokens.
     * @dev
     * The token amount must be specified in 18-decimal ERC20 units.
     * Pricing is derived from the current ETH/USD price provided by Chainlink.
     *
     * Example:
     * - tokenAmount = 1e18 (1 token)
     * - If 1 ETH = 2000 USD,
     *   the required ETH will be 0.0005 ETH.
     *
     * @param tokenAmount Amount of tokens to purchase (18 decimals).
     * @return totalPrice Amount of ETH (18 decimals) required for the purchase.
     */

    function getPriceForTokenAmount(uint256 tokenAmount) public view returns (uint256) {
        if (tokenAmount == 0) {
            revert EtherBeastToken__ZeroValue();
        } else if (tokenAmount < 1e18) {
            revert EtherBeastToken__BelowMinimumTopUp();
        }

        uint256 pricePerToken = _getEthAmountPerUsd();
        uint256 totalPrice = (pricePerToken * tokenAmount) / TOKEN_DECIMALS;

        return totalPrice;
    }

    /**
     * @notice Purchases EtherBeast tokens using ETH at a fixed USD price.
     * @dev
     * - Reverts if insufficient ETH is sent.
     * - Excess ETH is refunded to the caller.
     * - Tokens are minted directly to the buyer.
     *
     * Pricing is calculated at execution time using the latest ETH/USD price.
     * This function does not lock prices between transactions.
     *
     * @param tokenAmount Amount of tokens to purchase (18 decimals).
     */

    function buyToken(uint256 tokenAmount) external payable {
        uint256 totalPrice = getPriceForTokenAmount(tokenAmount);

        //check if user sends enough eth
        if (msg.value < totalPrice) {
            revert EtherBeastToken__SendMoreToBuyToken();
        }

        _mint(msg.sender, tokenAmount);

        if (msg.value > totalPrice) {
            uint256 refundValue = msg.value - totalPrice;
            (bool success,) = payable(msg.sender).call{value: refundValue}("");

            if (!success) {
                revert EtherBeastToken__TransferFailed();
            }
        }

        emit TokenPurchased(msg.sender, tokenAmount);
    }

    /*////////////////////////////////////////////////////////////////////////////
                             INTERNAL / PRIVATE FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the amount of ETH equivalent to 1 USD.
     * @dev
     * Uses the Chainlink ETH/USD price feed, which returns prices with 8 decimals.
     *
     * Example:
     * - If the price feed returns 2000e8 (1 ETH = 2000 USD),
     *   then 1 USD = 0.0005 ETH.
     *
     * All values are scaled to 18 decimals.
     * Multiplication is performed before division to avoid precision loss.
     *
     * @return ethAmountForOneUsd Amount of ETH (18 decimals) equal to 1 USD.
     */

    function _getEthAmountPerUsd() internal view returns (uint256 ethAmountForOneUsd) {
        (, int256 answer,,,) = AggregatorV3Interface(i_priceFeedAddress).latestRoundData();

        if (answer <= 0) revert EtherBeastToken__InvalidPrice();

        // 1 USD in 18 decimals token (virtual equal)
        uint256 usdPrecision = 1 * TOKEN_DECIMALS;

        // Price feed give answer in 8 decimal format, need to add padding to be 18 decimal
        uint256 answerPrecision = uint256(answer) * PRICE_FEED_PRECISION_PADDING;

        // PRECISION multiplied two times to prevent truncation
        ethAmountForOneUsd = (usdPrecision * PRECISION) / answerPrecision;
    }
}
