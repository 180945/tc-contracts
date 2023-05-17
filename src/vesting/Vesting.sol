// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// import VestingWallet
import "@openzeppelin-upgradeable/contracts/finance/VestingWalletUpgradeable.sol";

contract VestingWallet is VestingWalletUpgradeable {
    uint64 constant ONE_YEAR = 365 days;
    uint64 VestingDurationYears;

    function initialize(address beneficiaryAddress, uint64 startTimestamp) public initializer {
        VestingDurationYears = 1;
        __VestingWallet_init(beneficiaryAddress, startTimestamp, VestingDurationYears * ONE_YEAR);
    }

    function release() public override {
        super.release();
    }

    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view override returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp > start() + duration()) {
            return totalAllocation;
        } else {
            uint64 numYrs = uint64((timestamp - start()) / ONE_YEAR);
            if (numYrs > VestingDurationYears) {
                numYrs = VestingDurationYears;
            }
            return totalAllocation * numYrs / VestingDurationYears; // yearly-linear vesting
        }
    }



}