// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@safe-contracts/contracts/Safe.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/WToken.sol";
import "../src/bridgeTwoWays/Bridge.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/bridgeTwoWays/Proxy.sol";

contract TCScript is Script {
    address upgradeAddress;
    address operator;
//    address wrappedTokenImp;
//    address safeImp;
//    address bridgeImp;
    function setUp() public {
        upgradeAddress = 0x9699b31b25D71BDA4819bBe66244E9130cEE62b7;
//        wrappedTokenImp = 0x79DD392A7c352f0C47fB452c036EF08A1DA148C6;
//        safeImp = 0x47D453f4E494Ebb7264380d98D1C61420DfBB973;
//        bridgeImp = 0xa103f20367b18D004710141Ff505A6B63CE6885C;
        operator = 0x7286D69ed81DE05563264b9f4d47620B7768f318;
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

        Safe safeImp = new Safe();
        Safe safe = Safe(payable(address(new TransparentUpgradeableProxy(
            address(safeImp),
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

        address[] memory tokens = new address[](3);
        tokens[0] = 0xCAA77c6FB686b84Ffa16644a8588AABA66162cEC;
        tokens[1] = 0x205FB47E1151800B0Af7985aea1b63fAB61BbEF4;
        tokens[2] = 0x9A3c5B6D78cE858F9882D4444446643Bb5E8Ac45;

        // deploy tcbridge
        Bridge bridgeImp = new Bridge();
        Bridge bridge = Bridge(address(new TransparentUpgradeableProxy(
            address(bridgeImp),
            upgradeAddress,
            abi.encodeWithSelector(
                Bridge.initialize.selector,
                address(safe),
                operator,
                tokens
            )
        )));

        string memory BTC = "ORE";
        string memory ETH = "OXBT";
        string memory USDC = "ORDI";

        WrappedToken wrappedTokenImp = new WrappedToken();
        // deploy wrapped token
        WrappedToken oxbt = WrappedToken(address(new TransparentUpgradeableProxy(
            address(wrappedTokenImp),
            upgradeAddress,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                bridge,
                BTC,
                BTC
            )
        )));

        WrappedToken ore = WrappedToken(address(new TransparentUpgradeableProxy(
            address(wrappedTokenImp),
            upgradeAddress,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                bridge,
                ETH,
                ETH
            )
        )));

        WrappedToken ordi = WrappedToken(address(new TransparentUpgradeableProxy(
            address(wrappedTokenImp),
            upgradeAddress,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                bridge,
                USDC,
                USDC
            )
        )));

        vm.stopBroadcast();

        console.log("=== Deployment addresses ===");
        console.log("Safe address %s", address(safe));
        console.log("Bridge address  %s", address(bridge));
        console.log("ORE address  %s", address(oxbt));
        console.log("OXBT address  %s", address(ore));
        console.log("ORDI address  %s", address(ordi));
    }
}

contract TCScriptOnETH is Script {
    address upgradeAddress;
    address safeImp;
    address operator;
    //    address wrappedTokenImp;
    //    address bridgeImp;
    function setUp() public {
        upgradeAddress = 0x9699b31b25D71BDA4819bBe66244E9130cEE62b7;
        safeImp = 0xd154cFc746860697B6D63bb614449363F51D9cd6;
        operator = 0x7286D69ed81DE05563264b9f4d47620B7768f318;
        //        wrappedTokenImp = 0x79DD392A7c352f0C47fB452c036EF08A1DA148C6;
        //        bridgeImp = 0xa103f20367b18D004710141Ff505A6B63CE6885C;
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

        // Safe safeImp = new Safe();
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
        address[] memory tokens;
        Bridge bridgeImp = new Bridge();
        Bridge bridge = Bridge(address(new TransparentUpgradeableProxy(
            address(bridgeImp),
            upgradeAddress,
            abi.encodeWithSelector(
                Bridge.initialize.selector,
                address(safe),
                operator,
                tokens
            )
        )));

        // deploy proxy
        ProxyBridge proxyBridge = new ProxyBridge(
            0x330eFf2b5E5A02Dc8f63ac24637807f2c5737E5F,
            0xc60886596E7FaA7A14F05B2Eac94601d943206b9,
            address(safe),
            address(bridge),
            42069
        );

        vm.stopBroadcast();

        console.log("=== Deployment addresses ===");
        console.log("Safe address %s", address(safe));
        console.log("Bridge address  %s", address(bridge));
        console.log("Proxy address  %s", address(proxyBridge));
    }
}
