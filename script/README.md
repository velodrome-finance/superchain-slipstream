## Deploy CL

Deployment is straightforward. Hardhat scripts for deployment on tenderly are provided in script/hardhat.
This deployment assumes an existing Velodrome deployment exists.

### Environment Setup
1. Copy `.env.example` into a new `.env` file and set the environment variables. `PRIVATE_KEY_DEPLOY` is the private key to deploy all scripts.
2. Copy `script/constants/TEMPLATE.json` into a new file `script/constants/{CONSTANTS_FILENAME}`. For example, "Optimism.json" in the .env would be a file at location `script/constants/Optimism.json`. Set the variables in the new file.
3. Run tests to ensure deployment state is configured correctly:
```
forge init
forge build
forge test
```

### Deployment

Deploy Root Contracts

```
forge script script/deployParameters/optimism/DeployRootCL.s.sol:DeployRootCL --slow --rpc-url optimism -vvvv 
forge script script/deployParameters/optimism/DeployRootCL.s.sol:DeployRootCL --broadcast --slow --rpc-url optimism --broadcast --verify -vvvv 
```

Deploy Leaf Contracts

```
forge script script/deployParameters/mode/DeployLeafCL.s.sol:DeployLeafCL --slow --rpc-url mode -vvvv 
forge script script/deployParameters/mode/DeployLeafCL.s.sol:DeployLeafCL --broadcast --slow --rpc-url mode --broadcast --verify --verifier blockscout --verifier-url https://explorer.mode.network/api\? -vvvv 
```