

abi:
	mkdir -p abi
	jq '.abi' out/EtherBeastNFT.sol/EtherBeastNFT.json > abi/EtherBeastNFT.abi.json
	jq '.abi' out/EtherBeastGatcha.sol/EtherBeastGatcha.json > abi/EtherBeastGatcha.abi.json
	jq '.abi' out/EtherBeastToken.sol/EtherBeastToken.json > abi/EtherBeastToken.abi.json
	echo "ABIs generated in ./abi"

abi2:
	mkdir -p /mnt/e/Work/REPO/etherbeast-web3-reactjs/contract/abis
	cat out/EtherBeastNFT.sol/EtherBeastNFT.json | jq '.abi' > /mnt/e/Work/REPO/etherbeast-web3-reactjs/contract/abis/EtherBeastNFT.abi.json
	cat out/EtherBeastGatcha.sol/EtherBeastGatcha.json | jq '.abi' > /mnt/e/Work/REPO/etherbeast-web3-reactjs/contract/abis/EtherBeastGatcha.abi.json
	cat out/EtherBeastToken.sol/EtherBeastToken.json | jq '.abi' > /mnt/e/Work/REPO/etherbeast-web3-reactjs/contract/abis/EtherBeastToken.abi.json

RPC_URL := http://localhost:8545
PRIVATE_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
SCRIPT := script/DeployEtherBeast.s.sol:DeployEtherBeast

.PHONY: deploy deploy-local

deploy:
	@forge script $(SCRIPT) \
		--rpc-url $(RPC_URL) \
		--broadcast \
		--private-key $(PRIVATE_KEY) \
		-vvvv

deploy-local: deploy