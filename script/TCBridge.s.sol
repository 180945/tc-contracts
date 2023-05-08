// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@safe-contracts/contracts/Safe.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/WToken.sol";
import "../src/TCBridge.sol";
import "../src/ethereum/TCBridgeETH.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TCScript is Script {
    address upgradeAddress;
    function setUp() public {
        upgradeAddress = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy bridge tc contract
        address[] memory owners = new address[](7);
        owners[0] = address(0x142d09aCeA7b067639c8Dc4CF55fe907c5706c80);
        owners[1] = address(0x48519f5d37d4acE18011b5470EaaFDAf400079Cb);
        owners[2] = address(0x6c4ABD94C6eF3A8B092a673bE7D069F6A3a0c764);
        owners[3] = address(0xa32D154D0824C4d898b5A3b054E4aa0346322724);
        owners[4] = address(0x2550f37641FFB5e4928052aDDD788Cd8514d16a7);
        owners[5] = address(0xe64F53d154A25498870202aceff40A4344385a18);
        owners[6] = address(0x7d32913ad31Cdd2DAfA4eB024eF8fa0A3E6F9D95);

        Safe impl = new Safe();
        Safe safe = Safe(payable(address(new TransparentUpgradeableProxy(
            address(impl),
            upgradeAddress,
            abi.encodeWithSelector(
                Safe.setup.selector,
                owners,
                5,
                address(0x0),
                bytes(""),
                address(0x0),
                address(0x0),
                0,
                address(0)
            )
        ))));

        // deploy tcbridge
        TCBridge tcImpl = new TCBridge();
        TCBridge tcbridge = TCBridge(address(new TransparentUpgradeableProxy(
            address(tcImpl),
            upgradeAddress,
            abi.encodeWithSelector(
                TCBridge.initialize.selector,
                address(safe)
            )
        )));

        // deploy wrapped token
        WrappedToken wbrcImpl = new WrappedToken();
        WrappedToken(address(new TransparentUpgradeableProxy(
            address(wbrcImpl),
            upgradeAddress,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                address(tcbridge),
                "Wrapped BTC",
                "WBTC"
            )
        )));
        vm.stopBroadcast();
    }
}

contract Tether is ERC20  {
    constructor() ERC20("Tether", "USDT") {
        _mint(_msgSender(), 1e18);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract TCETHScript is Script {
    address upgradeAddress;
    function setUp() public {
        upgradeAddress = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy bridge tc contract
        address[] memory owners = new address[](7);
        owners[0] = address(0x142d09aCeA7b067639c8Dc4CF55fe907c5706c80);
        owners[1] = address(0x48519f5d37d4acE18011b5470EaaFDAf400079Cb);
        owners[2] = address(0x6c4ABD94C6eF3A8B092a673bE7D069F6A3a0c764);
        owners[3] = address(0xa32D154D0824C4d898b5A3b054E4aa0346322724);
        owners[4] = address(0x2550f37641FFB5e4928052aDDD788Cd8514d16a7);
        owners[5] = address(0xe64F53d154A25498870202aceff40A4344385a18);
        owners[6] = address(0x7d32913ad31Cdd2DAfA4eB024eF8fa0A3E6F9D95);

        Safe safe = Safe(payable(address(new TransparentUpgradeableProxy(
            address(0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552),
            upgradeAddress,
            abi.encodeWithSelector(
                Safe.setup.selector,
                owners,
                5,
                address(0x0),
                bytes(""),
                address(0x0),
                address(0x0),
                0,
                address(0)
            )
        ))));

        // deploy tcbridge
        TCBridgeETH(address(new TransparentUpgradeableProxy(
            address(new TCBridgeETH()),
            upgradeAddress,
            abi.encodeWithSelector(
                TCBridgeETH.initialize.selector,
                address(safe)
            )
        )));

        vm.stopBroadcast();
    }
}

contract TCDeployTokenScript is Script {
    address upgradeAddress;
    address wrappedTokenImp;
    address tcBridge;

    function setUp() public {
        upgradeAddress = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
        wrappedTokenImp = 0x79DD392A7c352f0C47fB452c036EF08A1DA148C6;
        tcBridge = 0x63bfaC4D88aeD85E0A0880E501Ed4B9E1D64A47b;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // deploy wrapped token
        WrappedToken(address(new TransparentUpgradeableProxy(
            wrappedTokenImp,
            upgradeAddress,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                tcBridge,
                "Wrapped PEPE",
                "WPEPE"
            )
        )));

        WrappedToken(address(new TransparentUpgradeableProxy(
            wrappedTokenImp,
            upgradeAddress,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                tcBridge,
                "Wrapped TURBO",
                "WTURBO"
            )
        )));

        vm.stopBroadcast();
    }
}