// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {SafeMathUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/math/SafeMathUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {MathUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/math/MathUpgradeable.sol";

library NumberMath {
    // CONST
    uint256 internal constant RATIO = 1e6;
    using SafeMathUpgradeable for uint256;

    uint256 internal constant ONE_ETHER = 1 ether;
    uint256 internal constant PRICE_UNIT = 0.000001 ether;
    uint256 internal constant NUMBER_UNIT_PER_ONE_ETHER =
    ONE_ETHER / PRICE_UNIT;

    uint256 internal constant PRICE_BTC_PER_TC = 0.000416666666666667 ether; // 1 BTC = 2400 TC
    uint256 internal constant PRICE_TC_PER_BTC = 2400 ether; // 1 BTC = 2400 TC
    uint256 internal constant PRICE_KEYS_DENOMINATOR = 264000;

    uint256 internal constant TS_30_DAYS = 30 days;

    uint24 internal constant SWAP_PLATFORM_FEE_RATIO = 10000;
    uint24 internal constant SWAP_CREATOR_FEE_RATIO = 40000;

    //
    function mulRatio(
        uint256 value,
        uint24 ratio
    ) internal pure returns (uint256) {
        return value.mul(ratio).div(RATIO);
    }

    function divRatio(
        uint256 value,
        uint24 ratio
    ) internal pure returns (uint256) {
        return value.mul(RATIO).div(ratio);
    }

    function mulEther(uint256 value) internal pure returns (uint256) {
        return value.mul(1 ether);
    }

    function divEther(uint256 value) internal pure returns (uint256) {
        return value.div(1 ether);
    }

    function mulPrice(
        uint256 value,
        uint256 rate
    ) internal pure returns (uint256) {
        return value.mul(rate).div(1 ether);
    }

    function roundMilliether(uint256 value) internal pure returns (uint256) {
        return value.div(0.001 ether).mul(0.001 ether);
    }

    function getPriceV2(
        uint256 supply,
        uint256 amount
    ) internal pure returns (uint256) {
        // invalid params
        require(supply >= NUMBER_UNIT_PER_ONE_ETHER && amount >= 1, "NM_IP");
        //
        uint256 sum1 = ((supply - NUMBER_UNIT_PER_ONE_ETHER) *
        supply *
            (2 *
            (supply - NUMBER_UNIT_PER_ONE_ETHER) +
                NUMBER_UNIT_PER_ONE_ETHER)) / 6;
        uint256 sum2 = ((supply - NUMBER_UNIT_PER_ONE_ETHER + amount) *
        (supply + amount) *
            (2 *
            (supply - NUMBER_UNIT_PER_ONE_ETHER + amount) +
                NUMBER_UNIT_PER_ONE_ETHER)) / 6;
        uint256 summation = sum2 - sum1;
        return
            (summation * ONE_ETHER) /
            PRICE_KEYS_DENOMINATOR /
            (NUMBER_UNIT_PER_ONE_ETHER *
            NUMBER_UNIT_PER_ONE_ETHER *
                NUMBER_UNIT_PER_ONE_ETHER);
    }

    function getBuyPriceV2(
        uint256 supply,
        uint256 amountX18
    ) internal pure returns (uint256) {
        return
            getPriceV2(supply.div(PRICE_UNIT), amountX18.div(PRICE_UNIT)).add(
            1
        );
    }

    function getBuyPriceV2AfterFee(
        uint24 protocolFeeRatio,
        uint24 playerFeeRatio,
        uint256 supply,
        uint256 amountX18
    ) internal pure returns (uint256) {
        //
        uint256 price = getBuyPriceV2(supply, amountX18);
        uint256 protocolFee = mulRatio(price, protocolFeeRatio);
        uint256 playerFee = mulRatio(price, playerFeeRatio);
        return price.add(protocolFee).add(playerFee);
    }

    function getBuyAmountMaxWithCash(
        uint24 protocolFeeRatio,
        uint24 playerFeeRatio,
        address token,
        uint256 buyPriceAfterFeeMax
    ) internal view returns (uint256) {
        uint256 supply = IERC20Upgradeable(token).totalSupply();
        uint256 amount = 0;
        for (uint i = 0; i < 6; i++) {
            uint256 delta = (ONE_ETHER / (10 ** i));
            while (true) {
                if (
                    getBuyPriceV2AfterFee(
                        protocolFeeRatio,
                        playerFeeRatio,
                        supply,
                        amount.add(delta)
                    ) > buyPriceAfterFeeMax
                ) {
                    break;
                }
                amount = amount.add(delta);
            }
        }
        return amount;
    }

    function getPaymentMaxFor(
        address token,
        address account,
        address spender
    ) internal view returns (uint256) {
        return
            MathUpgradeable.min(
            IERC20Upgradeable(token).balanceOf(account),
            IERC20Upgradeable(token).allowance(account, spender)
        );
    }

    function getBuyAmountMaxWithConditions(
        address token,
        uint24 protocolFeeRatio,
        uint24 playerFeeRatio,
        uint256 amountMax,
        uint256 buyPriceAfterFeeMax,
        uint256 amountBTC
    ) internal view returns (uint256) {
        uint256 supply = IERC20Upgradeable(token).totalSupply();
        uint256 amount = 0;
        for (uint i = 0; i < 6; i++) {
            uint256 delta = (ONE_ETHER / (10 ** i));
            while (true) {
                if (
                    getBuyPriceV2AfterFee(
                        protocolFeeRatio,
                        playerFeeRatio,
                        supply.add(amount.add(delta)),
                        0.1 ether
                    ).mul(10) >
                    buyPriceAfterFeeMax ||
                    amount.add(delta) > amountMax ||
                    getBuyPriceV2AfterFee(
                        protocolFeeRatio,
                        playerFeeRatio,
                        supply,
                        amount.add(delta)
                    ) >
                    amountBTC
                ) {
                    break;
                }
                amount = amount.add(delta);
            }
        }
        return amount;
    }

    function getStakingId(
        uint24 ratio,
        uint256 duration,
        bool locked
    ) internal pure returns (uint256) {
        require(ratio == (ratio / 1000) * 1000 && ratio >= 1000 && ratio <= 15000000, "NM_IR");
        require(duration < ONE_ETHER, "NM_ID");
        return
            (uint256(locked ? 1 : 0).mul(ONE_ETHER).mul(ONE_ETHER)).add(
            uint256(ratio).mul(ONE_ETHER).add(duration)
        );
    }
}