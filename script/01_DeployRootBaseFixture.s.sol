// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "./DeployFixture.sol";

import {RootCLPool} from "contracts/root/pool/RootCLPool.sol";
import {RootCLPoolFactory} from "contracts/root/pool/RootCLPoolFactory.sol";
import {RootCLGaugeFactory} from "contracts/root/gauge/RootCLGaugeFactory.sol";
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

    // root slipstream contracts
    RootCLPool public rootPoolImplementation;
    RootCLPoolFactory public rootPoolFactory;
    RootCLGaugeFactory public rootGaugeFactory;

    DeploymentParameters internal _params;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        address _deployer = deployer;

        rootPoolImplementation = RootCLPool(
            cx.deployCreate3({
                salt: CL_POOL_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(type(RootCLPool).creationCode)
            })
        );
        checkAddress({_entropy: CL_POOL_ENTROPY, _output: address(rootPoolImplementation)});

        rootPoolFactory = RootCLPoolFactory(
            cx.deployCreate3({
                salt: CL_POOL_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootCLPoolFactory).creationCode,
                    abi.encode(
                        _params.poolFactoryOwner, // owner
                        address(rootPoolImplementation), // pool implementation
                        _params.messageBridge // message bridge
                    )
                )
            })
        );
        checkAddress({_entropy: CL_POOL_FACTORY_ENTROPY, _output: address(rootPoolFactory)});

        rootGaugeFactory = RootCLGaugeFactory(
            cx.deployCreate3({
                salt: CL_GAUGE_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootCLGaugeFactory).creationCode,
                    abi.encode(
                        _params.voter, // root voter
                        _params.xVelo, // xerc20
                        _params.lockbox, // lockbox
                        _params.messageBridge, // message bridge
                        address(rootPoolFactory), // pool factory
                        _params.votingRewardsFactory, // voting rewards factory
                        _params.notifyAdmin, // notify admin
                        _params.emissionAdmin, // emission admin
                        100 // 1% default cap
                    )
                )
            })
        );
        checkAddress({_entropy: CL_GAUGE_FACTORY_ENTROPY, _output: address(rootGaugeFactory)});
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        if (isTest) return;
        console2.log("rootPoolImplementation: ", address(rootPoolImplementation));
        console2.log("rootPoolFactory: ", address(rootPoolFactory));
        console2.log("rootGaugeFactory: ", address(rootGaugeFactory));
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
                    stdJson.serialize("", "rootPoolImplementation", address(rootPoolImplementation)),
                    stdJson.serialize("", "rootPoolFactory", address(rootPoolFactory)),
                    stdJson.serialize("", "rootGaugeFactory", address(rootGaugeFactory))
                )
            )
        );
    }
}
