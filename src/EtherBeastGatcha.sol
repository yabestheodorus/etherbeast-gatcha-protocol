// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title EtherBeastGatcha
 * @author Yabes Theodorus
 * @notice Gacha contract that consumes EtherBeastToken to mint randomized EtherBeast NFTs using Chainlink VRF.
 * @dev
 * - Users pay a fixed token price per gacha roll.
 * - Tokens are burned immediately to guarantee payment.
 * - Randomness is provided by Chainlink VRF v2 Plus.
 * - Each user can have only one gacha roll in progress at a time.
 */

import {EtherBeastNFT} from "src/EtherBeastNFT.sol";
import {EtherBeastTypes} from "src/EtherBeastTypes.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {EtherBeastToken} from "src/EtherBeastToken.sol";

contract EtherBeastGatcha is VRFConsumerBaseV2Plus {
    /*////////////////////////////////////////////////////////////////////////////
                                          ERRORS
    ///////////////////////////////////////////////////////////////////////////*/

    error EtherBeastGatcha__ZeroValue();
    error EtherBeastGatcha__OutOfBound();
    error EtherBeastGatcha__InvalidArrayLength();
    error EtherBeastGatcha__GatchaNotIdle();
    error EtherBeastGatcha__InsufficientTokenBalance();
    error EtherBeastGatcha__TransferFailed();

    /*////////////////////////////////////////////////////////////////////////////
                                     TYPE DECLARATIONS
    ///////////////////////////////////////////////////////////////////////////*/

    enum GatchaState {
        Idle,
        Rolling
    }

    /*////////////////////////////////////////////////////////////////////////////
                                    STATE VARIABLES
    ///////////////////////////////////////////////////////////////////////////*/

    /// @notice ERC20 token used as payment for gacha
    EtherBeastToken private immutable i_token;

    /// @notice NFT contract where EtherBeasts are minted
    EtherBeastNFT private immutable i_Nft;

    /// @notice Fixed price per gacha roll (18 decimals)
    uint256 public constant GATCHA_PRICE_IN_TOKEN = 1e18;

    uint16 private constant MIN_HP = 15000;
    uint16 private constant MAX_HP = type(uint16).max;

    uint16 private constant MIN_ATTACK_DEF = 1500;
    uint16 private constant MAX_ATTACK_DEF = 4500;

    // VRF RELATEED CONSTANT
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant CALLBACK_GAS_LIMIT = 500_000;
    uint32 private constant NUM_WORDS = 1;

    mapping(uint8 => EtherBeastTypes.EtherBeast) private s_beastCatalog;
    uint8[] private s_beastIds;
    mapping(uint8 => string) private s_beastIdToImageURI;

    mapping(address => uint256) private s_userToRequestId;

    /// @notice Per-user gacha state to prevent concurrent rolls
    mapping(address => GatchaState) private s_userToGatchaState;

    /// @notice Maps VRF requestId to the requesting user
    mapping(uint256 => address) private s_requestIdToUser;

    /*////////////////////////////////////////////////////////////////////////////
                                          EVENTS
    ///////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a gacha roll starts and VRF randomness is requested
    event GatchaIsRolling(uint256 indexed requestId, address indexed user);

    /// @notice Emitted when a gacha roll is fulfilled and an NFT is minted
    event GatchaFulfilled(uint256 indexed requestId, address indexed user);

    /*////////////////////////////////////////////////////////////////////////////
                                        CONSTRUCTOR
    ///////////////////////////////////////////////////////////////////////////*/

    constructor(
        address payable token,
        address nftContract,
        uint8[] memory beastIds,
        uint8[] memory beastElements,
        string[] memory imageURI,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subsId
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        _predefineBeast(beastIds, beastElements, imageURI);

        i_token = EtherBeastToken(token);
        i_Nft = EtherBeastNFT(nftContract);
        i_keyHash = keyHash;
        i_subscriptionId = subsId;
    }

    /*////////////////////////////////////////////////////////////////////////////
                                   RECEIVE / FALLBACK
    ///////////////////////////////////////////////////////////////////////////*/

    /*////////////////////////////////////////////////////////////////////////////
                               PUBLIC / EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////*/

    function getImageURI(uint8 beastId) external view returns (string memory) {
        return s_beastIdToImageURI[beastId];
    }

    function checkGatchaState() public view returns (GatchaState) {
        return s_userToGatchaState[msg.sender];
    }

    /**
     * @notice Starts a gacha roll by charging tokens and requesting VRF randomness.
     * @dev
     * - Reverts if the user already has an ongoing gacha.
     * - Burns tokens immediately to guarantee payment even if VRF is delayed.
     * - Emits {GatchaIsRolling} with the VRF requestId.
     */
    function performGatcha() external {
        // CEI guideline (Check, Effect, Interaction)

        // Ensure user has enough tokens to pay for gacha
        if (i_token.balanceOf(msg.sender) < GATCHA_PRICE_IN_TOKEN) {
            revert EtherBeastGatcha__InsufficientTokenBalance();
        }

        // Prevent concurrent gacha requests per user
        if (checkGatchaState() != GatchaState.Idle) {
            revert EtherBeastGatcha__GatchaNotIdle();
        }

        // Pull tokens from user into this contract
        bool success = i_token.transferFrom(msg.sender, address(this), GATCHA_PRICE_IN_TOKEN);
        if (!success) {
            revert EtherBeastGatcha__TransferFailed();
        }

        // Burn immediately to guarantee payment even if VRF fulfillment is delayed or fails
        i_token.burn(GATCHA_PRICE_IN_TOKEN);

        // Request secure randomness from Chainlink VRF
        uint256 requestId = _requestRandomWords();

        // Mark user as rolling to block further gacha calls
        s_userToGatchaState[msg.sender] = GatchaState.Rolling;

        // Track request ownership
        s_userToRequestId[msg.sender] = requestId;
        s_requestIdToUser[requestId] = msg.sender;

        // emit event
        emit GatchaIsRolling(requestId, msg.sender);
    }

    /*////////////////////////////////////////////////////////////////////////////
                             INTERNAL / PRIVATE FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////*/

    function _predefineBeast(uint8[] memory beastIds, uint8[] memory beastElements, string[] memory imageURI) internal {
        if ((beastIds.length != beastElements.length) || (beastIds.length != imageURI.length)) {
            revert EtherBeastGatcha__InvalidArrayLength();
        }

        // pre defined the beast
        for (uint256 i = 0; i < beastIds.length; i++) {
            // if at least one of the id or elements contain zero value, it will reverted
            if ((beastIds[i] == 0) || (beastElements[i] == 0)) {
                revert EtherBeastGatcha__ZeroValue();
            }
            if ((beastElements[i] > uint8(EtherBeastTypes.EtherBeastElement.Thunder))) {
                revert EtherBeastGatcha__OutOfBound();
            }
            EtherBeastTypes.EtherBeast memory beast = EtherBeastTypes.EtherBeast({
                id: beastIds[i],
                rarity: EtherBeastTypes.EtherBeastRarity.None,
                hp: 0,
                attack: 0,
                defense: 0,
                element: EtherBeastTypes.EtherBeastElement(beastElements[i])
            });
            s_beastIds.push(beastIds[i]);
            s_beastCatalog[beastIds[i]] = beast;
            s_beastIdToImageURI[beastIds[i]] = imageURI[i];
        }
    }

    /**
     * @notice Requests verifiable randomness from Chainlink VRF.
     * @dev Returns a unique requestId used to correlate fulfillment.
     */
    function _requestRandomWords() internal returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
    }

    /**
     * @notice Callback executed by Chainlink VRF with verified randomness.
     * @dev
     * - Derives multiple independent random values from a single VRF word.
     * - Determines beast type, stats, and rarity.
     * - Mints the NFT and resets user gacha state.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 randomWord = randomWords[0];

        // Base entropy seed derived from VRF output and requestId
        // requestId ensures uniqueness even if VRF word repeats
        bytes32 baseSeed = keccak256(abi.encode(randomWord, requestId));

        // Select a random predefined beast ID Index
        uint256 randBeastId = uint256(keccak256(abi.encode(baseSeed, "BEAST"))) % s_beastIds.length;

        // Generate stats within bounded ranges to avoid extreme values
        uint16 hp = uint16(uint256(keccak256(abi.encode(baseSeed, "HP"))) % (MAX_HP - MIN_HP + 1)) + MIN_HP;
        uint16 attack = uint16(uint256(keccak256(abi.encode(baseSeed, "ATK"))) % (MAX_ATTACK_DEF - MIN_ATTACK_DEF + 1))
            + MIN_ATTACK_DEF;
        uint16 defense = uint16(uint256(keccak256(abi.encode(baseSeed, "DEF"))) % (MAX_ATTACK_DEF - MIN_ATTACK_DEF + 1))
            + MIN_ATTACK_DEF;

        // PROBABILITIES
        // Common : 50%
        // RARE : 30%
        // UNIQUE : 15%
        // LEGENDARY : 5%

        // Probability-based rarity selection (50/30/15/5)
        uint16 randRarity = uint16(uint256(keccak256(abi.encode(baseSeed, "RARITY"))) % 100 + 1);

        EtherBeastTypes.EtherBeastRarity rarity;

        if (randRarity <= 50) {
            rarity = EtherBeastTypes.EtherBeastRarity.Common;
        } else if (randRarity <= 80) {
            rarity = EtherBeastTypes.EtherBeastRarity.Rare;
        } else if (randRarity <= 95) {
            rarity = EtherBeastTypes.EtherBeastRarity.Unique;
        } else {
            rarity = EtherBeastTypes.EtherBeastRarity.Legendary;
        }

        uint8 beastId = s_beastIds[randBeastId];
        EtherBeastTypes.EtherBeastElement element = s_beastCatalog[beastId].element;

        // Reset user state BEFORE external calls to avoid reentrancy risk
        address to = s_requestIdToUser[requestId];
        s_userToGatchaState[to] = GatchaState.Idle;

        // Cleanup request tracking to avoid stale storage
        delete s_userToRequestId[to];
        delete s_requestIdToUser[requestId];

        emit GatchaFulfilled(requestId, to);

        // Mint NFT last (external interaction)
        i_Nft.mintNft(to, beastId, rarity, hp, attack, defense, element);
    }

    /*////////////////////////////////////////////////////////////////////////////
                               GETTER FUNCTIONS
    ///////////////////////////////////////////////////////////////////////////*/

    function getBeastIds() external view returns (uint8[] memory) {
        return s_beastIds;
    }

    function getBeastById(uint8 beastId) external view returns (EtherBeastTypes.EtherBeast memory) {
        return s_beastCatalog[beastId];
    }

    function getRequestId() external view returns (uint256 requestId) {
        requestId = s_userToRequestId[msg.sender];
    }
}
