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
    address wrappedTokenImp;
    address safeImp;
    address tcbridgeImp;
    function setUp() public {
        upgradeAddress = 0xE7143319283D0b5b234AEA046769D40bee5C6D43;
//        wrappedTokenImp = 0x79DD392A7c352f0C47fB452c036EF08A1DA148C6;
//        safeImp = 0x47D453f4E494Ebb7264380d98D1C61420DfBB973;
//        tcbridgeImp = 0xa103f20367b18D004710141Ff505A6B63CE6885C;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        safeImp = address(new Safe());
        tcbridgeImp = address(new TCBridge());
        wrappedTokenImp = address(new WrappedToken());

        // deploy bridge tc contract
        address[] memory owners = new address[](7);
        owners[0] = address(0x990F4bAb2EEE01E74A5D180120eFA5267D17FC67);
        owners[1] = address(0xCe91d43217b95cdB0974a40FAe776E80Db3A7cdd);
        owners[2] = address(0x66bfb1A5EAbf746f5faC5A24E35C5fAa28A881A7);
        owners[3] = address(0x11FF5A145EDAE91C9a6ea8E1E0740F1A71a8b72B);
        owners[4] = address(0x93Fc71ebb6ECFaB8681769b205202894935BB2be);
        owners[5] = address(0xBa8b1B1E0DB0A771C6A513662b2B3F75FBa39D47);
        owners[6] = address(0xA2FFf21B05827406010A49e621632e31Ff349009);

        Safe safe = Safe(payable(address(new TransparentUpgradeableProxy(
            safeImp,
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
        TCBridge tcBridge = TCBridge(address(new TransparentUpgradeableProxy(
            tcbridgeImp,
            upgradeAddress,
            abi.encodeWithSelector(
                TCBridge.initialize.selector,
                address(safe)
            )
        )));

        // deploy wrapped token
        WrappedToken oxbt = WrappedToken(address(new TransparentUpgradeableProxy(
            wrappedTokenImp,
            upgradeAddress,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                tcBridge,
                "ETH",
                "ETH"
            )
        )));

        WrappedToken ore = WrappedToken(address(new TransparentUpgradeableProxy(
            wrappedTokenImp,
            upgradeAddress,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                tcBridge,
                "BTC",
                "BTC"
            )
        )));

        WrappedToken ordi = WrappedToken(address(new TransparentUpgradeableProxy(
            wrappedTokenImp,
            upgradeAddress,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                tcBridge,
                "USDC",
                "USDC"
            )
        )));
        vm.stopBroadcast();

        console.log("=== Deployment addresses ===");
        console.log("Safe address %s", address(safe));
        console.log("TCBridge address  %s", address(tcBridge));
        console.log("ETH address  %s", address(oxbt));
        console.log("BTC address  %s", address(ore));
        console.log("USDC address  %s", address(ordi));
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
        owners[0] = address(0x990F4bAb2EEE01E74A5D180120eFA5267D17FC67);
        owners[1] = address(0xCe91d43217b95cdB0974a40FAe776E80Db3A7cdd);
        owners[2] = address(0x66bfb1A5EAbf746f5faC5A24E35C5fAa28A881A7);
        owners[3] = address(0x11FF5A145EDAE91C9a6ea8E1E0740F1A71a8b72B);
        owners[4] = address(0x93Fc71ebb6ECFaB8681769b205202894935BB2be);
        owners[5] = address(0xBa8b1B1E0DB0A771C6A513662b2B3F75FBa39D47);
        owners[6] = address(0xA2FFf21B05827406010A49e621632e31Ff349009);

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