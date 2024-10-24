// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import {CLPool} from "../CLPool.sol";
import {ICLPoolActions} from "../interfaces/ICLPool.sol";
import {IFeeSharing} from "../../extensions/interfaces/IFeeSharing.sol";
import {IModeFeeSharing} from "../../extensions/interfaces/IModeFeeSharing.sol";

contract ModeCLPool is CLPool {
    /// @inheritdoc ICLPoolActions
    function initialize(
        address _factory,
        address _token0,
        address _token1,
        int24 _tickSpacing,
        uint160 _sqrtPriceX96,
        address _gauge,
        address _nft
    ) public override {
        super.initialize({
            _factory: _factory,
            _token0: _token0,
            _token1: _token1,
            _tickSpacing: _tickSpacing,
            _sqrtPriceX96: _sqrtPriceX96,
            _gauge: _gauge,
            _nft: _nft
        });

        address sfs = IModeFeeSharing(_factory).sfs();
        uint256 tokenId = IModeFeeSharing(_factory).tokenId();
        IFeeSharing(sfs).assign(tokenId);
    }
}
