// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface IMinter {
    /// @notice Starting weekly emission of 15M VELO (VELO has 18 decimals)
    function weekly() external view returns (uint256);

    /// @notice Tail emissions rate in basis points
    function tailEmissionRate() external view returns (uint256);

    /// @notice Timestamp of start of epoch that updatePeriod was last called in
    function activePeriod() external view returns (uint256);

    /// @notice Address of token issued by Minter
    function velo() external view returns (address);

    /// @notice Processes emissions and rebases. Callable once per epoch (1 week).
    /// @return _period Start of current epoch.
    function updatePeriod() external returns (uint256 _period);
}
