# NFT Marketplace - NFT 市场合约

基于 Foundry 的 NFT 市场智能合约项目，包含安全修复和生产级优化。

## 📖 项目概述

这是一个 NFT 交易市场合约，支持：
- NFT 上架和购买
- 签名验证上架
- 平台手续费
- UUPS 合约升级

## 📁 项目结构

```
nft-marketplace/
├── src/
│   ├── NFTMarketplace.sol         # 原始版本 (有安全漏洞)
│   ├── NFTMarketplaceV2.sol      # V2 版本
│   ├── NFTMarketplaceFixed.sol   # 生产安全版本 ⭐
│   ├── NFTMarketplace-uups.sol   # UUPS 升级版
│   ├── NFTMarketplace-uupsV2.sol
│   ├── MyNFT.sol                # 测试 NFT
│   └── MyToken.sol              # 测试代币
└── lib/                          # 依赖库
```

## 🔐 安全修复记录 (7步法 - Modify/Refactor)

### 原始版本的安全问题

```solidity
// ❌ 原始版本有严重安全漏洞：
function buy(address nftAddress, uint256 tokenId) public {
    // 1. 先转钱 - 如果这里成功
    token.transferFrom(msg.sender, listing.seller, price);
    
    // 2. 再转 NFT - 如果这里失败，钱已经没了！
    IERC721(nftAddress).safeTransferFrom(seller, msg.sender, tokenId);
    
    delete listings[nftAddress][tokenId];
}
```

### 问题列表

| # | 问题 | 严重程度 | 描述 |
|---|------|---------|------|
| 1 | 重入攻击 | 🔴 高 | 没有重入保护，可能被攻击 |
| 2 | 转账顺序错误 | 🔴 高 | 先转钱再转 NFT，如果 NFT 转账失败，钱没了 |
| 3 | 签名已弃用 | 🟡 中 | 使用弃用的 ecrecover |
| 4 | 无手续费 | 🟢 低 | 缺少平台运营收入 |
| 5 | 无紧急暂停 | 🟢 低 | 缺少紧急功能 |

### 修复方案

```solidity
// ✅ 修复后的版本：
function buy(address nftAddress, uint256 tokenId) external nonReentrant {
    // ============ Checks ============
    Listing memory listing = listings[nftAddress][tokenId];
    if (listing.seller == address(0)) revert NotListed();
    
    // ============ Effects ============
    uint256 price = listing.price;
    delete listings[nftAddress][tokenId];
    accumulatedFees += fee;
    emit NFTBought(...);
    
    // ============ Interactions ============
    // 1. 先转 NFT
    IERC721(nftAddress).safeTransferFrom(seller, msg.sender, tokenId);
    
    // 2. 再转钱
    token.transferFrom(msg.sender, seller, sellerAmount);
}
```

### 修复对比

| 修复项 | 原始版本 | 修复版本 |
|--------|----------|----------|
| 重入保护 | ❌ 无 | ✅ ReentrancyGuard |
| 转账顺序 | ❌ 钱→NFT | ✅ NFT→钱 |
| 签名验证 | ❌ ecrecover | ✅ ECDSA |
| 手续费 | ❌ 无 | ✅ 2.5% |
| CEI 模式 | ❌ 违反 | ✅ 遵守 |

## 🛠 技术栈

- **语言**: Solidity 0.8.25
- **框架**: Foundry
- **库**: OpenZeppelin Contracts

## 🚀 快速开始

### 安装依赖

```bash
forge install
```

### 编译

```bash
forge build
```

### 测试

```bash
forge test
```

## 📜 核心功能

### 1. 上架 NFT

```solidity
function list(address nftAddress, uint256 tokenId, uint256 price) external;
```

### 2. 购买 NFT

```solidity
function buy(address nftAddress, uint256 tokenId) external nonReentrant;
```

### 3. 签名上架

```solidity
function listWithSignature(
    address nftAddress,
    uint256 tokenId,
    uint256 price,
    bytes calldata signature
) external;
```

### 4. 取消上架

```solidity
function cancelListing(address nftAddress, uint256 tokenId) external;
```

### 5. 提取手续费

```solidity
function withdrawFees() external onlyOwner;
```

## 🔒 安全特性

- ✅ 重入保护 (ReentrancyGuard)
- ✅ Checks-Effects-Interactions 模式
- ✅ ECDSA 签名验证
- ✅ 平台手续费
- ✅ UUPS 合约升级

## 📝 学习记录

本项目使用 **7步工程学习法**：

1. **Run** - 运行项目，编译通过
2. **Map** - 理解项目结构
3. **Trace** - 追踪数据流
4. **Modify** - 发现安全问题
5. **Rebuild** - 重写核心逻辑
6. **Refactor** - 生产级优化 + 安全修复
7. **Teach** - 输出文档

## 📄 License

MIT
