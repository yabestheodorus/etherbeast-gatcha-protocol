// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title EtherBeastNFT
 * @author Yabes Theodorus
 * @notice ERC721 NFT contract representing EtherBeast creatures for a gacha system.
 * @dev Inherits from ERC721 and ERC721Enumerable. Each NFT has stats (HP, Attack, Defense),
 * a rarity, an element, and links to image URIs stored in the EtherBeastGatcha contract.
 */

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EtherBeastGatcha} from "src/EtherBeastGatcha.sol";
import {EtherBeastTypes} from "src/EtherBeastTypes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EtherBeastNFT is ERC721, ERC721Enumerable, Ownable {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    error EtherBeastNFT__InvalidTokenId();
    error EtherBeastNFT__InvalidBeastId();
    error EtherBeastNFT__ZeroValue();
    error EtherBeastNFT__NotFromGatchaContract();

    /*//////////////////////////////////////////////////////////////
                         STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from tokenId to EtherBeast struct
    mapping(uint256 => EtherBeastTypes.EtherBeast) private s_tokenToEtherBeast;

    /// @notice Counter for minted token IDs
    uint256 private s_tokenId;

    /// @notice Address of the authorized gacha contract
    address private s_gatchaContract;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new EtherBeast NFT is minted
    /// @param to Recipient of the NFT
    /// @param tokenId Token ID minted
    event EtherBeastMinted(address indexed to, uint256 tokenId);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures that only the gacha contract can call certain functions
    modifier onlyFromGatchaContract() {
        if (msg.sender != s_gatchaContract) {
            revert EtherBeastNFT__NotFromGatchaContract();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() ERC721("EtherBeast", "ETB") Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL / PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the EtherBeast NFT contract and sets the gacha contract address
    /// @param gatchaContract Address of the gacha contract authorized to mint NFTs
    function setGatchaContract(address gatchaContract) external onlyOwner {
        s_gatchaContract = gatchaContract;
    }

    /**
     * @notice Mints a new EtherBeast NFT to a specified address
     * @dev Can only be called by the gacha contract
     * @param to Recipient address
     * @param beastId Predefined beast ID
     * @param rarity Rarity of the beast
     * @param hp Hit points
     * @param attack Attack stat
     * @param defense Defense stat
     * @param element Element type of the beast
     */
    function mintNft(
        address to,
        uint8 beastId,
        EtherBeastTypes.EtherBeastRarity rarity,
        uint16 hp,
        uint16 attack,
        uint16 defense,
        EtherBeastTypes.EtherBeastElement element
    ) external onlyFromGatchaContract {
        if (beastId == 0) revert EtherBeastNFT__ZeroValue();
        if (rarity == EtherBeastTypes.EtherBeastRarity.None) revert EtherBeastNFT__ZeroValue();
        if (hp == 0 || attack == 0 || defense == 0) revert EtherBeastNFT__ZeroValue();

        s_tokenToEtherBeast[s_tokenId] = EtherBeastTypes.EtherBeast({
            id: beastId, rarity: rarity, hp: hp, attack: attack, defense: defense, element: element
        });

        _safeMint(to, s_tokenId);
        emit EtherBeastMinted(to, s_tokenId);
        s_tokenId++;
    }

    /**
     * @notice Returns the token URI for a given token ID, formatted as base64 JSON
     * @param tokenId ID of the token
     * @return Base64-encoded JSON metadata URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        EtherBeastTypes.EtherBeast memory beast = s_tokenToEtherBeast[tokenId];

        if (beast.id == 0) {
            revert EtherBeastNFT__InvalidTokenId();
        }

        bytes memory jsonByte = abi.encodePacked(
            '{ "name": "EtherBeast #',
            Strings.toString(tokenId),
            '", "image": "',
            EtherBeastGatcha(s_gatchaContract).getImageURI(beast.id),
            '", "attributes":[',
            '{"trait_type":"HP","value":',
            Strings.toString(beast.hp),
            "},",
            '{"trait_type":"Attack","value":',
            Strings.toString(beast.attack),
            "},",
            '{"trait_type":"Defense","value":',
            Strings.toString(beast.defense),
            "},",
            '{"trait_type":"Rarity","value":"',
            _rarityToString(beast.rarity),
            '"},',
            '{"trait_type":"Element","value":"',
            _elementToString(beast.element),
            '"}',
            "]}"
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(jsonByte)));
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL / PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _rarityToString(EtherBeastTypes.EtherBeastRarity r) internal pure returns (string memory) {
        if (r == EtherBeastTypes.EtherBeastRarity.Common) return "Common";
        if (r == EtherBeastTypes.EtherBeastRarity.Rare) return "Rare";
        if (r == EtherBeastTypes.EtherBeastRarity.Unique) return "Unique";
        return "Legendary";
    }

    function _elementToString(EtherBeastTypes.EtherBeastElement e) internal pure returns (string memory) {
        if (e == EtherBeastTypes.EtherBeastElement.Fire) return "Fire";
        if (e == EtherBeastTypes.EtherBeastElement.Ice) return "Ice";
        if (e == EtherBeastTypes.EtherBeastElement.Nature) return "Nature";
        return "Thunder";
    }

    /*//////////////////////////////////////////////////////////////
                         OVERRIDES FOR MULTIPLE INHERITANCE
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    /*//////////////////////////////////////////////////////////////
                         GETTERS
    //////////////////////////////////////////////////////////////*/
    function getBeastByTokenId(uint256 tokenId) public view returns (EtherBeastTypes.EtherBeast memory) {
        return s_tokenToEtherBeast[tokenId];
    }

    function getBeastsTokenURIsByOwner() external view returns (string[] memory tokenURIs, uint256[] memory tokenIds) {
        uint256 balance = balanceOf(msg.sender);
        tokenURIs = new string[](balance);
        tokenIds = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(msg.sender, i);
            tokenIds[i] = tokenId;
            tokenURIs[i] = tokenURI(tokenId);
        }
    }
}
