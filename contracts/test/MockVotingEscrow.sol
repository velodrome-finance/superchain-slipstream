// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import {IVotingEscrow} from "contracts/core/interfaces/IVotingEscrow.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockVotingEscrow is IVotingEscrow, ERC721 {
    address public immutable override team;

    constructor(address _team) ERC721("veNFT", "veNFT") {
        team = _team;
    }

    function isApprovedOrOwner(address _spender, uint256 _tokenId) external view override returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    function createLock(uint256, uint256) external pure override returns (uint256) {
        return 0;
    }
}
