// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title EtherBeastTypes
 * @author Yabes Theodorus
 * @notice Short description of contract
 * @dev Created 2025
 */

library EtherBeastTypes {
    struct EtherBeast {
        uint8 id;
        EtherBeastRarity rarity;
        uint16 hp;
        uint16 attack;
        uint16 defense;
        EtherBeastElement element;
    }

    enum EtherBeastRarity {
        None, // 0 = not minted
        Common,
        Rare,
        Unique,
        Legendary
    }

    enum EtherBeastElement {
        None, // 0 = not minted
        Fire,
        Ice,
        Nature,
        Thunder
    }
}
