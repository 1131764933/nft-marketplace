// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/MyNFT.sol";
import "../src/NFTMarketplace.sol";
import "../src/NFTMarketplaceV2.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // 部署自定义的 ERC20 Token 合约
        MyToken token = new MyToken(1000 * 10 ** 18);

        // 部署 ERC721 NFT 合约
        MyNFT nft = new MyNFT();

        // 部署 NFT Marketplace 合约的第一个版本
        NFTMarketplace marketplaceV1 = new NFTMarketplace();

        // 部署 NFT Marketplace 合约的第二个版本
        NFTMarketplaceV2 marketplaceV2 = new NFTMarketplaceV2();

        // 部署 ProxyAdmin 合约
        ProxyAdmin proxyAdmin = new ProxyAdmin(address(this));  // 传递一个地址作为参数

        // 部署 TransparentUpgradeableProxy 合约，并指向第一个版本的实现合约
        bytes memory data = abi.encodeWithSelector(NFTMarketplace.initialize.selector, address(token));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(marketplaceV1),
            address(proxyAdmin),
            data
        );

        vm.stopBroadcast();

        // 打印合约地址
        console.log("MyToken address:", address(token));
        console.log("MyNFT address:", address(nft));
        console.log("NFTMarketplaceV1 address:", address(marketplaceV1));
        console.log("NFTMarketplaceV2 address:", address(marketplaceV2));
        console.log("ProxyAdmin address:", address(proxyAdmin));
        console.log("TransparentUpgradeableProxy address:", address(proxy));
    }
}
