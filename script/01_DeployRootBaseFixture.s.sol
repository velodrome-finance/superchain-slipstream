// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "./DeployFixture.sol";

import {RootCLPool} from "contracts/mainnet/pool/RootCLPool.sol";
import {RootCLPoolFactory} from "contracts/mainnet/pool/RootCLPoolFactory.sol";
import {CLRootGaugeFactory} from "contracts/mainnet/gauge/CLRootGaugeFactory.sol";
import {Constants} from "script/constants/Constants.sol";

abstract contract DeployRootBaseFixture is DeployFixture, Constants {
    using stdJson for string;
    using CreateXLibrary for bytes11;

    struct DeploymentParameters {
        address voter;
        address xVelo;
        address lockbox;
        address messageBridge;
        address votingRewardsFactory;
        address poolFactoryOwner;
        address feeManager;
        address notifyAdmin;
        address emissionAdmin;
        string outputFilename;
    }

    // deployed
    RootCLPool public poolImplementation;
    RootCLPoolFactory public poolFactory;
    CLRootGaugeFactory public gaugeFactory;

    DeploymentParameters internal _params;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        poolImplementation = RootCLPool(
            cx.deployCreate3({
                salt: CL_POOL_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(type(RootCLPool).creationCode)
            })
        );
        checkAddress({_entropy: CL_POOL_ENTROPY, _output: address(poolImplementation)});

        poolFactory = RootCLPoolFactory(
            cx.deployCreate3({
                salt: CL_POOL_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootCLPoolFactory).creationCode,
                    abi.encode(
                        _params.poolFactoryOwner, // owner
                        address(poolImplementation), // pool implementation
                        _params.messageBridge // message bridge
                    )
                )
            })
        );
        checkAddress({_entropy: CL_POOL_FACTORY_ENTROPY, _output: address(poolFactory)});

        gaugeFactory = CLRootGaugeFactory(
            cx.deployCreate3({
                salt: CL_GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(CLRootGaugeFactory).creationCode,
                    abi.encode(
                        _params.voter, // root voter
                        _params.xVelo, // xerc20
                        _params.lockbox, // lockbox
                        _params.messageBridge, // message bridge
                        address(poolFactory), // pool factory
                        _params.votingRewardsFactory, // voting rewards factory
                        _params.notifyAdmin, // notify admin
                        _params.emissionAdmin, // emission admin
                        100 // 1% default cap
                    )
                )
            })
        );
        checkAddress({_entropy: CL_GAUGE_FACTORY_ENTROPY, _output: address(gaugeFactory)});
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        if (isTest) return;
        console2.log("poolImplementation: ", address(poolImplementation));
        console2.log("poolFactory: ", address(poolFactory));
        console2.log("gaugeFactory: ", address(gaugeFactory));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        /// @dev This might overwrite an existing output file
        vm.writeJson(
            path,
            string(
                abi.encodePacked(
                    stdJson.serialize("", "poolImplementation", address(poolImplementation)),
                    stdJson.serialize("", "poolFactory", address(poolFactory)),
                    stdJson.serialize("", "gaugeFactory", address(gaugeFactory))
                )
            )
        );
    }
}
