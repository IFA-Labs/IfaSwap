# Load .env file
include .env
export $(shell sed 's/=.*//' .env)

# Deploy to Sepolia
deploy-sepolia:
	@forge script script/deploy.s.sol:DeploySwap \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(private_key) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify \
		--broadcast
		

# Deploy to Base Sepolia
deploy-base-sepolia:
	@forge script script/deploy.s.sol:DeploySwap \
		--rpc-url $(BASE_SEPOLIA_RPC_URL) \
		--private-key $(private_key) \
		--etherscan-api-key $(BASESCAN_API_KEY) \
		--verify \
		--broadcast