## Deploy 

Fill out the parameters as required in `foundry.toml`.

### Deployment

Deploy Root Contracts

```
forge script script/deployParameters/optimism/DeployRootCL.s.sol:DeployRootCL --slow --rpc-url optimism -vvvv 
forge script script/deployParameters/optimism/DeployRootCL.s.sol:DeployRootCL --broadcast --slow --rpc-url optimism --verify -vvvv 
```

Deploy Leaf Contracts

Replace `leaf` with the chain you are deploying to.

```
forge script script/deployParameters/leaf/DeployLeafCL.s.sol:DeployLeafCL --slow --rpc-url leaf -vvvv 
forge script script/deployParameters/leaf/DeployLeafCL.s.sol:DeployLeafCL --broadcast --slow --rpc-url leaf --verify -vvvv 
```

If there is a verification failure, simply remove `--broadcast` and add `--resume`.

For blockscout verifications, append `--verifier blockscout` after `--verify`