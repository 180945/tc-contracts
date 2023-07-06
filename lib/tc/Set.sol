// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

library Set {
    struct Uint256Set {
        uint256[] values;
        mapping(uint256 => uint256) positions;
    }

    error ValueNotFound();
    error DuplicatedValue();

    function insert(Uint256Set storage _set, uint256 _value) internal {
        if (_set.positions[_value] != 0) revert DuplicatedValue();
        _set.values.push(_value);
        _set.positions[_value] = _set.values.length;
    }

    function erase(Uint256Set storage _set, uint256 _value) internal {
        uint256 p = _set.positions[_value];
        if (p == 0) revert ValueNotFound();
        (_set.values[p - 1], _set.values[_set.values.length - 1])
            = (_set.values[_set.values.length - 1], _set.values[p - 1]);
        _set.positions[_set.values[p - 1]] = p;
        _set.values.pop();
        _set.positions[_value] = 0;
    }

    function hasValue(Uint256Set storage _set, uint256 _value) internal view returns (bool) {
        return _set.positions[_value] != 0;
    }
}
