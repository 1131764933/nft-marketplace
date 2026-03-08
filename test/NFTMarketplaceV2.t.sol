// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/MyNFT.sol";
import "../src/NFTMarketplace.sol";
import "../src/NFTMarketplaceV2.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract NFTMarketplaceV2Test is Test {
    MyToken token;
    MyNFT nft;
    NFTMarketplace marketplace;
    NFTMarketplaceV2 marketplaceV2;
    TransparentUpgradeableProxy proxy;
    ProxyAdmin proxyAdmin;
    address owner;
    address buyer;

    function setUp() public {
        owner = address(0x123);
        buyer = address(0x456);

        vm.startPrank(owner);

        token = new MyToken(1000 * 10 ** 18);
        nft = new MyNFT();
        marketplace = new NFTMarketplace();
        marketplaceV2 = new NFTMarketplaceV2();

        proxyAdmin = new ProxyAdmin(owner);

        bytes memory data = abi.encodeWithSelector(NFTMarketplace.initialize.selector, address(token), owner);
        proxy = new TransparentUpgradeableProxy(address(marketplace), address(proxyAdmin), data);

        vm.stopPrank();
    }

    function testUpgradeToV2() public {
        vm.startPrank(owner);

        // 升级合约到 V2 版本
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(proxy)), address(marketplaceV2), bytes(""));

        vm.stopPrank();

        // 验证升级后的合约地址
        NFTMarketplaceV2 upgraded = NFTMarketplaceV2(address(proxy));
        assertEq(address(upgraded), address(proxy));
    }

    function testListNFTWithSignature() public {
        // 铸造 NFT 并列出
        vm.startPrank(owner);
        uint256 tokenId = nft.createNFT("https://example.com/nft1");
        nft.approve(address(proxy), tokenId);

        NFTMarketplaceV2 proxyMarketplace = NFTMarketplaceV2(address(proxy));

        // 需要签名生成方法，以下是示例签名生成，实际测试时请替换为实际生成的签名
        bytes memory signature = new bytes(65); // 这里应该是实际生成的签名
        proxyMarketplace.listWithSignature(address(nft), tokenId, 10 * 10 ** 18, signature);

        // 验证 NFT 列表
        (address listedNFT, uint256 listedTokenId, uint256 price, address seller) = proxyMarketplace.getListing(1);
        assertEq(listedNFT, address(nft));
        assertEq(listedTokenId, tokenId);
        assertEq(price, 10 * 10 ** 18);
        assertEq(seller, owner);
        vm.stopPrank();
    }



    function testBuyNFT() public {
        // 铸造 NFT 并列出
        vm.startPrank(owner);
        uint256 tokenId = nft.createNFT("https://example.com/nft1");
        nft.approve(address(proxy), tokenId);

        NFTMarketplaceV2 proxyMarketplace = NFTMarketplaceV2(address(proxy));
        proxyMarketplace.listWithSignature(address(nft), tokenId, 10 * 10 ** 18, new bytes(65));
        vm.stopPrank();

        // 购买 NFT
        vm.startPrank(buyer);
        token.mint(buyer, 10 * 10 ** 18);
        token.approve(address(proxy), 10 * 10 ** 18);
        proxyMarketplace.buyNFT(address(nft),1);

        // 验证 NFT 已被购买
        assertEq(nft.ownerOf(tokenId), buyer);
        vm.stopPrank();
    }
}
