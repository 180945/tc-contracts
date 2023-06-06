// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/WToken.sol";
import "../src/bridgeTwoWays/Bridge.sol";
import "@safe-contracts/contracts/Safe.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./MockToken.sol";

contract TCBridgeTest is Test {
    address public constant ADMIN_ADDR = address(10);
    WrappedToken public wbtc;
    Bridge public bridge;
    Safe public safe;
    address public o1 = address(0x9699b31b25D71BDA4819bBe66244E9130cEE62b7);
    uint256 public prv1 = uint256(0x1193a43543fc11e37daa1a026ae8fae69d84c5dd1f3f933047ff2588778c5cca);

    address public o2 = address(0x54b3DBA467C9Dbb916EF4D6AedaFa19C4Fef8258);
    uint256 public prv2 = uint256(0x15681448451d0a925d17408e6c3f33a3e1b5a60b89ab5096c2381a37ab58e234);

    address public o3 = address(0xD7d93b7fa42b60b6076f3017fCA99b69257A912D);
    uint256 public prv3 = uint256(0xaad53b70ad9ed01b75238533dd6b395f4d300427da0165aafbd42ea7a606601f);

    address constant USER_1 = address(11);
    address constant USER_2 = address(12);
    address constant USER_3 = address(13);

    // events
    event Mint(WrappedToken[] tokens, address[] recipients, uint[] amounts);
    event Mint(WrappedToken token, address[] recipients, uint[] amounts);
    event BridgeToken(WrappedToken token, address burner, uint amount, string btcAddr);

    function setUp() public {
        // deploy multisig wallet
        address[] memory owners = new address[](3);
        owners[0] = o1;
        owners[1] = o2;
        owners[2] = o3;

        Safe impl = new Safe();
        safe = Safe(payable(address(new TransparentUpgradeableProxy(
            address(impl),
            ADMIN_ADDR,
            abi.encodeWithSelector(
                Safe.setup.selector,
                owners,
                2,
                address(0x0),
                bytes(""),
                address(0x0),
                address(0x0),
                0,
                address(0)
            )
        ))));

        // deploy bridge
        Bridge bridgeImp = new Bridge();
        bridge = Bridge(address(new TransparentUpgradeableProxy(
            address(bridgeImp),
            ADMIN_ADDR,
            abi.encodeWithSelector(
                Bridge.initialize.selector,
                address(safe)
            )
        )));

        assertEq(bridge.owner(), address(safe));

        // deploy wrapped token
        WrappedToken wbrcImpl = new WrappedToken();
        wbtc = WrappedToken(address(new TransparentUpgradeableProxy(
            address(wbrcImpl),
            ADMIN_ADDR,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                address(bridge),
                "Test",
                "T"
            )
        )));
    }
    
    function testMint() public {
        // execute mint token

        // build data
        WrappedToken[] memory tokens = new WrappedToken[](2);
        tokens[0] = wbtc;
        tokens[1] = wbtc;

        address[] memory recipients = new address[](2);
        recipients[0] = USER_1;
        recipients[1] = USER_3;

        uint[] memory amounts = new uint[](2);
        amounts[0] = 1e18;
        amounts[1] = 10e18;

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        bridge.mint(tokens, recipients, amounts);

        bytes memory mintCallData = abi.encodeWithSelector(
            bytes4(keccak256("mint(address[],address[],uint256[])")),
            tokens,
            recipients,
            amounts
        );
        // request mint token to USER_1 USER_3
        bytes memory encodeTx = safe.encodeTransactionData(
            address(bridge),
            0,
            mintCallData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            ADMIN_ADDR,
            safe.nonce()
        );
        bytes32 txHash = keccak256(encodeTx);
        bytes memory signatures;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(prv2, txHash);
        signatures = abi.encodePacked(signatures, r, s, v);

        (v, r, s) = vm.sign(prv1, txHash);
        signatures = abi.encodePacked(signatures, r, s, v);

        // execute tx
        safe.execTransaction(
            address(bridge),
            0,
            mintCallData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(ADMIN_ADDR),
            signatures
        );

        assertEq(wbtc.balanceOf(USER_1), 1e18);
        assertEq(wbtc.balanceOf(USER_3), 10e18);

        WrappedToken token = wbtc;

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        bridge.mint(token, recipients, amounts);

        mintCallData = abi.encodeWithSelector(
            bytes4(keccak256("mint(address,address[],uint256[])")),
            token,
            recipients,
            amounts
        );
        // request mint token to USER_1 USER_3
        encodeTx = safe.encodeTransactionData(
            address(bridge),
            0,
            mintCallData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            ADMIN_ADDR,
            safe.nonce()
        );
        txHash = keccak256(encodeTx);
        (v, r, s) = vm.sign(prv2, txHash);
        signatures = abi.encodePacked(r, s, v);

        (v, r, s) = vm.sign(prv1, txHash);
        signatures = abi.encodePacked(signatures, r, s, v);

        // execute tx
        safe.execTransaction(
            address(bridge),
            0,
            mintCallData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(ADMIN_ADDR),
            signatures
        );

        assertEq(wbtc.balanceOf(USER_1), 2e18);
        assertEq(wbtc.balanceOf(USER_3), 20e18);
    }

    function testBurn() public {
        testMint();

        // new token owner
        address tokenOwner = address(100);
        string memory sampleAddress = "0x9699b31b25D71BDA4819bBe66244E9130cEE62b7";

        // create new token
        WrappedToken newToken = WrappedToken(address(new MockToken("test", "T", 18, 0)));
        WrappedToken newToken2 = WrappedToken(address(new MockToken2("test", "T", 18, 0, tokenOwner)));

        // mint new tokens to users
        vm.startPrank(tokenOwner);
        newToken.mint(USER_1, 1e20);
        newToken.mint(USER_2, 4e20);
        newToken.mint(USER_3, 16e20);

        newToken2.mint(USER_1, 1e20);
        newToken2.mint(USER_2, 1e20);
        vm.stopPrank();
        // mint native token
        vm.deal(USER_1, 5 * 1e18);
        vm.deal(USER_2, 5 * 1e18);
        vm.deal(USER_3, 5 * 1e18);

        // call bridge token function
        vm.startPrank(USER_1);
        wbtc.approve(address(bridge), 1e30);
        newToken.approve(address(bridge), 1e30);
        newToken2.approve(address(bridge), 1e30);

        vm.expectEmit(false, false, false, true);
        emit BridgeToken(newToken, USER_1, 1e18, sampleAddress);
        bridge.bridgeToken(newToken, 1e18, sampleAddress);
        assertEq(newToken.balanceOf(address(bridge)), 1e18);

        vm.expectEmit(false, false, false, true);
        emit BridgeToken(wbtc, USER_1, 1e16, sampleAddress);
        bridge.bridgeToken(wbtc, 1e16, sampleAddress);
        assertEq(wbtc.balanceOf(address(bridge)), 0);

        vm.expectEmit(false, false, false, true);
        emit BridgeToken(newToken2, USER_1, 1e18, sampleAddress);
        bridge.bridgeToken(newToken2, 1e18, sampleAddress);
        assertEq(newToken2.balanceOf(address(bridge)), 1e18);
        vm.stopPrank();

        vm.prank(USER_2);
        vm.expectEmit(false, false, false, true);
        emit BridgeToken(WrappedToken(address(0)), USER_2, 1e18, sampleAddress);
        bridge.bridgeToken{value: 1e18}(sampleAddress);
        assertEq(address(bridge).balance, 1e18);

        // build data
        WrappedToken[] memory tokens = new WrappedToken[](3);
        tokens[0] = wbtc;
        tokens[1] = newToken2;
        tokens[2] = WrappedToken(address(0));

        address[] memory recipients = new address[](3);
        recipients[0] = address(201);
        recipients[1] = address(202);
        recipients[2] = address(203);

        uint[] memory amounts = new uint[](3);
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        amounts[2] = 1e18;

        bytes memory mintCallData = abi.encodeWithSelector(
            bytes4(keccak256("mint(address[],address[],uint256[])")),
            tokens,
            recipients,
            amounts
        );
        // request mint tokens
        bytes memory encodeTx = safe.encodeTransactionData(
            address(bridge),
            0,
            mintCallData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            ADMIN_ADDR,
            safe.nonce()
        );
        bytes32 txHash = keccak256(encodeTx);
        bytes memory signatures;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(prv2, txHash);
        signatures = abi.encodePacked(signatures, r, s, v);

        (v, r, s) = vm.sign(prv1, txHash);
        signatures = abi.encodePacked(signatures, r, s, v);

        // execute tx
        safe.execTransaction(
            address(bridge),
            0,
            mintCallData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(ADMIN_ADDR),
            signatures
        );

        assertEq(wbtc.balanceOf(address(201)), 1e18);
        assertEq(newToken2.balanceOf(address(202)), 1e18);
        assertEq(address(203).balance, 1e18);
    }
}
