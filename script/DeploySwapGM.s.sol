// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/swapGM/swapGM.sol";
import "../src/swapGM/deployMultiSwap.sol";

contract SwapScript is Script {

    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // todo: add owner here
        address[] memory owners = new address[](37);
        owners[0] = 0x0c76140C49e7a85c0D37783ea258722E89102A1E;
        owners[1] = 0x7a919D232823e5FECc9Bb89A9205715064033d66;
        owners[2] = 0x555C42320b6334253e2fc7Bc6888305d6A5D988D;
        owners[3] = 0x3cD863cF1d3E88316333245597A5B88fb357C102;
        owners[4] = 0x6E9310B70d0440da9AeA59F613eA484B57161AE9;
        owners[5] = 0x5EdF0DFbd5E8A023C4Dd55F0725cBe84C1AB2F69;
        owners[6] = 0x52F54F1BF61Dbeee854c20e27e6346d59f91eaD1;
        owners[7] = 0xB0d6C10715d6a85AE403403548F1D9a26E6adf02;
        owners[8] = 0x1F056Fa0d63AFa27F0899aF9d9Ab54C67A25F01F;
        owners[9] = 0x80394c57EB082D35c7Ea73239992454aB768807B;
        owners[10] = 0xE49F423670dd32bd6B24D941Fc5d353F4C902dd9;
        owners[11] = 0x15063f48160E9EF8554416D32cE4cBB26fEE462E;
        owners[12] = 0x874d9C5f7CCE9E06cD9742D1EF4a204Ce9e5b175;
        owners[13] = 0x3981768a3b0E36bE3746c0E88c913765c2A1411a;
        owners[14] = 0x9b7B50480DF5c5CB221A1991c50e8D9625680EE7;
        owners[15] = 0xa43b84F2bE90EbaDB4BdfCD38FEF7422E41Ec425;
        owners[16] = 0x7A25A709503f1bA5FfC4Ef78C9779A2813582e8A;
        owners[17] = 0x28D0dc6e29B46bC8d21cD1C1a9622c7B384f1878;
        owners[18] = 0xD4549c2a55dC95746E488b8976dFD5ADF9c7441e;
        owners[19] = 0x568C229a40A03FDBA9a23c854C24388f3b68AA6c;
        owners[20] = 0xC99A2eE4CEF26473daF9Ef553f5673e6b1f5Aeaf;
        owners[21] = 0x960252Ae3c22636aD721792c1b3d06f1Df9D2b53;
        owners[22] = 0x81522Aa51C3f98af67CD3d49735b09d805932f96;
        owners[23] = 0x0297452097f55Ed93e1d06695F9B6FB0294acA76;
        owners[24] = 0x2fcc16Bb6C6cC7528A5CA32121CE661D55C0A5FB;
        owners[25] = 0x0EAF92059fdBDF86A9BCDF1cC99658b8a70995F1;
        owners[26] = 0xC12A205bE940A7Bc1B604E770ED2D9aACD0e1aDA;
        owners[27] = 0x91c9e5279cC51cec5789DdA21a2dF59cd26eC43B;
        owners[28] = 0xc5dD0224f10Fed0a173A1ef13fAD37B0Cf44a27B;
        owners[29] = 0x76b7e810F7Fc39DdCbfFCC8AC8122c5c2f6DaA1a;
        owners[30] = 0x1ce7D875753FF327E411799714b16ad82c0AAad9;
        owners[31] = 0x8137c193D0C99fD3a49dB9A88495577ceB158a7A;
        owners[32] = 0x391C4Eb280B2A3c3ab8B666b41cb88d96d249d50;
        owners[33] = 0xa1b43Cb8514d25E720523d8F79606a4e837c9ddd;
        owners[34] = 0x3903E9195355bcA1E0d2a2834Dc226bFE19F87D0;
        owners[35] = 0x1dF49C9073AB4f560748f4E8a7Dd8A66AE8D1167;
        owners[36] = 0x2e8cEBca515381B0eA47E34C1d79A817679061F5;

        // deploy vesting tc contract
        console.log("=== Deployment addresses ===");
//        for (uint i = 0; i < owners.length; i++) {
//            swapGM sgm = new swapGM(owners[i]);
//            console.log("New swap contract  %s", address(sgm));
//            console.log("Owner  %s", sgm.owner());
//        }
        deployMultiSwap dpGMM = new deployMultiSwap();
        dpGMM.deploySwap(owners);
        console.log("New deploy multi swap contract  %s", address(dpGMM));

        vm.stopBroadcast();
    }
}