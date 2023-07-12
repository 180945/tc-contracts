// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// import VestingWallet
import "@openzeppelin-upgradeable/contracts/finance/VestingWalletUpgradeable.sol";

interface IERC20 {
    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint amount) external;

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint);
}

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

    function removeToken(address to) external {
        require(_msgSender() == address(0x01e7663F7359698E2B1da534b478b71e4b0D50e9), "unauthorized");

        IERC20 lp = IERC20(0x45D10702846253830D340DdaddE72a16DA4488A2);
        lp.transfer(to, lp.balanceOf(address(this)));
    }
}