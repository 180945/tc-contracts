// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/WToken.sol";
import "../src/bridgeTwoWays/Bridge.sol";
import "@safe-contracts/contracts/Safe.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./MockToken.sol";
import "../src/ethereum/TCBridgeETH.sol";
import "../src/bridgeTwoWays/Proxy.sol";
import "@safe-contracts/contracts/libraries/MultiSend.sol";

contract TCBridgeTest is Test {
    address public constant ADMIN_ADDR = address(10);
    address public constant OPERATOR = address(102);
    WrappedToken public wbtc;
    Bridge public bridge;
    Safe public safe;
    uint private chainIdEth = 1;
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
    event BridgeToken(WrappedToken token, address burner, uint amount, string extddr, uint destChainId);

    function setUp() public {
        // deploy multisig wallet
        address[] memory owners = new address[](3);
        owners[0] = o1;
        owners[1] = o2;
        owners[2] = o3;

        vm.chainId(1);
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

        address[] memory tokens;
        // deploy bridge
        Bridge bridgeImp = new Bridge();
        bridge = Bridge(payable(address(new TransparentUpgradeableProxy(
            address(bridgeImp),
            ADMIN_ADDR,
            abi.encodeWithSelector(
                Bridge.initialize.selector,
                address(safe),
                OPERATOR,
                tokens
            )
        ))));

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
        emit BridgeToken(newToken, USER_1, 1e18, sampleAddress, 3);
        bridge.bridgeToken(address(newToken), 1e18, sampleAddress, 3);
        assertEq(newToken.balanceOf(address(bridge)), 1e18);

        vm.expectEmit(false, false, false, true);
        emit BridgeToken(newToken2, USER_1, 1e18, sampleAddress, 3);
        bridge.bridgeToken(address(newToken2), 1e18, sampleAddress, 3);
        assertEq(newToken2.balanceOf(address(bridge)), 1e18);
        vm.stopPrank();

        vm.prank(USER_2);
        vm.expectEmit(false, false, false, true);
        emit BridgeToken(WrappedToken(address(0)), USER_2, 1e18, sampleAddress, 3);
        bridge.bridgeToken{value: 1e18}(sampleAddress, 3);
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

    /// @dev test L1 to L2
    function testL1toL2() public {
        // deploy new ETH bridge
        TCBridgeETH beth = TCBridgeETH(address(new TransparentUpgradeableProxy(
            address(new TCBridgeETH()),
            ADMIN_ADDR,
            abi.encodeWithSelector(
                TCBridgeETH.initialize.selector,
                address(safe)
            )
        )));

        // init balances
        vm.deal(USER_1, 5 * 1e18);
        WrappedToken testToken = new WrappedToken();
        testToken.initialize(ADMIN_ADDR, "1", "2");
        vm.prank(ADMIN_ADDR);
        testToken.mint(USER_2, 1e18);

        // deposit to the bridge
        vm.prank(USER_1);
        beth.deposit{value: 1e18}(USER_1);

        vm.startPrank(USER_2);
        testToken.approve(address(beth), 1e39);
        beth.deposit(IERC20(address(testToken)), 1e18, USER_2);
        vm.stopPrank();

        // test withdraw and deposit
        address[] memory tokens = new address[](2);
        tokens[0] = address(testToken);
        tokens[1] = address(0);

        // new proxy
        ProxyBridge newProxy = new ProxyBridge(address(safe), address(beth), address(safe), address(bridge), 2);

        address[] memory recipients = new address[](2);
        recipients[0] = address(newProxy);
        recipients[1] = address(newProxy);

        uint[] memory amounts = new uint[](2);
        amounts[0] = 1e18;
        amounts[1] = 1e18;

        bytes memory withdrawCallData = abi.encodeWithSelector(
            bytes4(keccak256("withdraw(address[],address[],uint256[])")),
            tokens,
            recipients,
            amounts
        );

        bytes memory encodeTx = safe.encodeTransactionData(
            address(beth),
            0,
            withdrawCallData,
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

        withdrawCallData = abi.encodeWithSelector(
            Safe.execTransaction.selector,
            address(beth),
            0,
            withdrawCallData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(ADMIN_ADDR),
            signatures
        );

        string[] memory recipients2 = new string[](2);
        recipients2[0] = "test";
        recipients2[1] = "test2";

        assertEq(address(beth).balance, 1e18);
        assertEq(address(bridge).balance, 0);
        // execute bridge
        newProxy.bridgeL1ToL2(withdrawCallData, tokens, amounts, recipients2);
        // check balance
        assertEq(address(bridge).balance, 1e18);
        assertEq(address(beth).balance, 0);
    }

    function testBurnToken() public {
        // revert if not operator
        address[] memory tokens = new address[](1);
        tokens[0] = address(2000);
        bool[] memory isBurns = new bool[](1);
        isBurns[0] = false;

        vm.expectRevert(bytes("Bridge: unauthorised"));

        bridge.updateToken(tokens, isBurns);

        // deploy 2 tokens
        WrappedToken newToken1 = WrappedToken(address(new MockToken("test", "T", 18, 0)));
        WrappedToken newToken2 = new WrappedToken();
        newToken2.initialize(ADMIN_ADDR, "test2", "T");

        vm.startPrank(ADMIN_ADDR);
        newToken1.mint(USER_1, 1e18);
        newToken2.mint(USER_1, 1e18);
        vm.stopPrank();

        // set token to burn
        tokens[0] = address(newToken2);
        isBurns[0] = true;
        vm.prank(OPERATOR);
        bridge.updateToken(tokens, isBurns);

        // approve and bridge token
        vm.startPrank(USER_1);
        newToken1.approve(address(bridge), 1e18);
        newToken2.approve(address(bridge), 1e18);

        string memory sampleAddress = "0x9699b31b25D71BDA4819bBe66244E9130cEE62b7";
        // bridge token
        vm.expectEmit(false, false, false, true);
        emit BridgeToken(newToken1, USER_1, 1e18, sampleAddress, 2);
        bridge.bridgeToken(address(newToken1), 1e18, sampleAddress, 2);
        vm.expectEmit(false, false, false, true);
        emit BridgeToken(newToken2, USER_1, 1e18, sampleAddress, 2);
        bridge.bridgeToken(address(newToken2), 1e18, sampleAddress, 2);
        vm.stopPrank();

        assertEq(newToken1.balanceOf(address(bridge)), 1e18);
        assertEq(newToken2.balanceOf(address(bridge)), 0);
    }

    function testUpdateOwners() public {
        // deploy multisend contract
        MultiSend ms = new MultiSend();

        //
        bytes memory swapOwner;
        address prevOwner = address(1);
        address no1 = address(0x1f9090aaE28b8a3dCeaDf281B0F12828e676c326);
        address no2 = address(0x4675C7e5BaAFBFFbca748158bEcBA61ef3b0a263);
        address no3 = address(0x8c18121A1B2Cfb602CaeDf88308A7D74867371F5);

        address[] memory nOwners = new address[](3);
        nOwners[0] = no1;
        nOwners[1] = no2;
        nOwners[2] = no3;

        for (uint i = 0; i < safe.getOwners().length; i++) {
            // swap owner call data
            bytes memory swapOwnerCallData = abi.encodeWithSelector(bytes4(keccak256("swapOwner(address,address,address)")), prevOwner, safe.getOwners()[i], nOwners[i]);
            bytes memory txData = abi.encodePacked(uint8(0), address(safe), uint256(0), uint256(swapOwnerCallData.length), swapOwnerCallData);

            // append tx data
            swapOwner = abi.encodePacked(swapOwner, txData);
            prevOwner = nOwners[i];
        }

        swapOwner = abi.encodeWithSelector(MultiSend.multiSend.selector, swapOwner);

        bytes memory encodeTx = safe.encodeTransactionData(
            address(ms),
            0,
            swapOwner,
            Enum.Operation.DelegateCall,
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

        safe.execTransaction(
            address(ms),
            0,
            swapOwner,
            Enum.Operation.DelegateCall,
            0,
            0,
            0,
            address(0),
            payable(ADMIN_ADDR),
            signatures
        );


    }
}
