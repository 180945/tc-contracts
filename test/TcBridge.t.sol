// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/WToken.sol";
import "../src/TCBridge.sol";
import "@safe-contracts/contracts/Safe.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TCBridgeTest is Test {
    address public constant ADMIN_ADDR = address(10);
    WrappedToken public wbtc;
    TCBridge public tcbridge;
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

    event Burn(WrappedToken token, address burner, uint amount, string btcAddr);

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

        // deploy tcbridge
        TCBridge tcImpl = new TCBridge();
        tcbridge = TCBridge(address(new TransparentUpgradeableProxy(
            address(tcImpl),
            ADMIN_ADDR,
            abi.encodeWithSelector(
                TCBridge.initialize.selector,
                address(safe)
            )
        )));

        assertEq(tcbridge.owner(), address(safe));

        // deploy wrapped token
        WrappedToken wbrcImpl = new WrappedToken();
        wbtc = WrappedToken(address(new TransparentUpgradeableProxy(
            address(wbrcImpl),
            ADMIN_ADDR,
            abi.encodeWithSelector(
                WrappedToken.initialize.selector,
                address(tcbridge),
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
        tcbridge.mint(tokens, recipients, amounts);

        bytes memory mintCallData = abi.encodeWithSelector(
            bytes4(keccak256("mint(address[],address[],uint256[])")),
            tokens,
            recipients,
            amounts
        );
        // request mint token to USER_1 USER_3
        bytes memory encodeTx = safe.encodeTransactionData(
            address(tcbridge),
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
            address(tcbridge),
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
        tcbridge.mint(token, recipients, amounts);

        mintCallData = abi.encodeWithSelector(
            bytes4(keccak256("mint(address,address[],uint256[])")),
            token,
            recipients,
            amounts
        );
        // request mint token to USER_1 USER_3
        encodeTx = safe.encodeTransactionData(
            address(tcbridge),
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
            address(tcbridge),
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
        // burn token

        string memory btcAddr = "bc1q8ylkr8c9scej96hkdhrj96632rwu2gtf72prus";

        vm.startPrank(USER_1);
        wbtc.approve(address(tcbridge), 1e18);
        vm.expectEmit(false, false, false, true);
        emit Burn(wbtc, USER_1, 1e18, btcAddr);
        tcbridge.burn(wbtc, 1e18, btcAddr);
        vm.stopPrank();

        address[] memory owners = new address[](7);
        owners[0] = address(0xF165DBE65127feca0abbD7d734B4a2a3c3C6aA84);
        owners[1] = address(0xd1950Ce1cd947B0F0378c9eB9618b705A13539A2);
        owners[2] = address(0x2150E0F033f2F8E8c13Fe2089A0cB399521604FF);
        owners[3] = address(0x9B9e024D6C2a9c3eF921497FbE53c57a851321cd);
        owners[4] = address(0xd85f5f63E83bDec8a92dd3C7f7FaEFE671024d85);
        owners[5] = address(0xD898eE20D858da55A7A58D1069BD47be234dC50f);
        owners[6] = address(0xB39310E75b773876dBa6006aDeE116BC40363994);

        console.logBytes(abi.encodeWithSelector(
            Safe.setup.selector,
            owners,
            5,
            address(0x0),
            bytes(""),
            address(0x0),
            address(0x0),
            0,
            address(0)
        ));

        console.logBytes(abi.encodeWithSelector(
            TCBridge.initialize.selector,
            address(safe)
        ));

        console.logBytes(abi.encodeWithSelector(
            WrappedToken.initialize.selector,
            address(tcbridge),
            "Wrapped BTC",
            "WBTC"
        ));

        // create mint tx
        WrappedToken token = WrappedToken(0xd154cFc746860697B6D63bb614449363F51D9cd6);

        address[] memory recipients = new address[](2);
        recipients[0] = address(0x9699b31b25D71BDA4819bBe66244E9130cEE62b7);
        recipients[1] = address(0x54b3DBA467C9Dbb916EF4D6AedaFa19C4Fef8258);

        uint[] memory amounts = new uint[](2);
        amounts[0] = 1000e18;
        amounts[1] = 10000e18;

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        tcbridge.mint(token, recipients, amounts);

        bytes memory mintCallData = abi.encodeWithSelector(
            bytes4(keccak256("mint(address,address[],uint256[])")),
            token,
            recipients,
            amounts
        );
        console.logBytes(mintCallData);

        // sort private keys by address
        uint[] memory owner_privs = new uint[](7);
        quickSort(owners, owner_privs, 0, int256(owners.length - 1));

        bytes memory encodeTx = fromHex("190152da2698b7d0719b18e8197b0148212aca90fb4c2363ccc7252c3c7a347997b4c5fd2de1670df1a89e998a29c93c548e9b928f9d0403ca31b3ccf96f1e9f23bc");
        bytes32 txHash = keccak256(encodeTx);
        bytes memory signatures;

//        for (uint i = 0; i < owner_privs.length; i++){
//            (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner_privs[i], txHash);
//            signatures = abi.encodePacked(signatures, r, s, v);
//        }
//
//        console.logBytes(signatures);
    }

    // Convert an hexadecimal string to raw bytes
    function fromHex(string memory s) public pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length%2 == 0); // length must be even
        bytes memory r = new bytes(ss.length/2);
        for (uint i=0; i<ss.length/2; ++i) {
            r[i] = bytes1(fromHexChar(uint8(ss[2*i])) * 16 +
            fromHexChar(uint8(ss[2*i+1])));
        }
        return r;
    }

    // Convert an hexadecimal character to their value
    function fromHexChar(uint8 c) public pure returns (uint8) {
        if (bytes1(c) >= bytes1('0') && bytes1(c) <= bytes1('9')) {
            return c - uint8(bytes1('0'));
        }
        if (bytes1(c) >= bytes1('a') && bytes1(c) <= bytes1('f')) {
            return 10 + c - uint8(bytes1('a'));
        }
        if (bytes1(c) >= bytes1('A') && bytes1(c) <= bytes1('F')) {
            return 10 + c - uint8(bytes1('A'));
        }
        revert("fail");
    }

    function quickSort(address[] memory arr, uint[] memory arr2, int left, int right) public pure {
        int i = left;
        int j = right;
        if (i == j) return;
        address pivot = arr[uint(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint(i)] < pivot) i++;
            while (pivot < arr[uint(j)]) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                (arr2[uint(i)], arr2[uint(j)]) = (arr2[uint(j)], arr2[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, arr2, left, j);
        if (i < right)
            quickSort(arr, arr2, i, right);
    }

}
