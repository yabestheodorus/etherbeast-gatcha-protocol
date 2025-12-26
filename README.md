# 🐉 EtherBeast

**EtherBeast** is a Web3 gacha-style NFT system built on Ethereum.  
It combines a native ERC20 token, provable randomness via **Chainlink VRF**, and a burn-to-summon mechanic to mint ERC721 NFTs with verifiable rarity.

This project is designed as a **real smart-contract system**, not a demo:
- deterministic rules
- explicit state machines
- strict validation
- test-driven development

---

## ✨ Features

- **ERC20 Utility Token**
  - Buy with ETH using Chainlink price feeds
  - Minimum top-up enforced
  - Overpayment refunded
  - Tokens are burned to perform gacha

- **Gacha System**
  - Uses Chainlink VRF v2.5
  - Burn-to-summon model
  - State-locked execution (Idle → Rolling → Fulfilled)
  - Probability-based rarity distribution

- **ERC721 NFTs**
  - Minted only by the Gacha contract
  - Predefined beast catalog
  - Deterministic attributes + random rarity

---

## 🧠 Architecture
User
├─ buys EtherBeastToken (ETH → ERC20)
├─ approves Gatcha contract
└─ calls performGatcha()
├─ burns ERC20 token
├─ requests VRF randomness
└─ VRF callback mints NFT



**Randomness is provable.**  
No admin-controlled outcomes. No simulated RNG.

---

## 📦 Contracts

| Contract | Description |
|--------|-------------|
| `EtherBeastToken.sol` | ERC20 token with ETH pricing |
| `EtherBeastGatcha.sol` | Gacha logic & VRF integration |
| `EtherBeastNFT.sol` | ERC721 NFT contract |
| `EtherBeastTypes.sol` | Shared enums & structs |
| `DeployEtherBeast.s.sol` | Full system deployment |
| `HelperConfig.s.sol` | Network configuration |
| `Interaction.s.sol` | VRF subscription helpers |

---

## 🎲 Randomness & Fairness

- Chainlink **VRF v2.5**
- Subscription-based
- Consumer explicitly registered
- No post-mint manipulation
- Gacha cannot complete without VRF fulfillment

If randomness does not arrive, the gacha **does not resolve**.

---

## 🧪 Testing

Testing follows strict separation:
- no mega test files
- shared deployment via `BaseTest`
- explicit revert testing
- real VRF mocks
- gas usage visible per test



---

## 🚀 Deployment
Local (Anvil)
anvil
forge script script/DeployEtherBeast.s.sol --broadcast --rpc-url http://localhost:8545

Testnet / Mainnet

## Requirements:

- VRF subscription created
- Subscription funded with LINK
- Gatcha contract added as consumer

 Deployment script handles:
- subscription creation
- funding
- consumer registration

## 📜 License

MIT

