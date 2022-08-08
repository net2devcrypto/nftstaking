// SPDX-License-Identifier: MIT LICENSE


/*

Follow/Subscribe Youtube, Github, IM, Tiktok
for more amazing content!!
@Net2Dev
███╗░░██╗███████╗████████╗██████╗░██████╗░███████╗██╗░░░██╗
████╗░██║██╔════╝╚══██╔══╝╚════██╗██╔══██╗██╔════╝██║░░░██║
██╔██╗██║█████╗░░░░░██║░░░░░███╔═╝██║░░██║█████╗░░╚██╗░██╔╝
██║╚████║██╔══╝░░░░░██║░░░██╔══╝░░██║░░██║██╔══╝░░░╚████╔╝░
██║░╚███║███████╗░░░██║░░░███████╗██████╔╝███████╗░░╚██╔╝░░
╚═╝░░╚══╝╚══════╝░░░╚═╝░░░╚══════╝╚═════╝░╚══════╝░░░╚═╝░░░
THIS CONTRACT IS AVAILABLE FOR EDUCATIONAL 
PURPOSES ONLY. YOU ARE SOLELY REPONSIBLE 
FOR ITS USE. I AM NOT RESPONSIBLE FOR ANY
OTHER USE. THIS IS TRAINING/EDUCATIONAL
MATERIAL. ONLY USE IT IF YOU AGREE TO THE
TERMS SPECIFIED ABOVE.
*/

pragma solidity 0.8.4;

import "https://github.com/net2devcrypto/n2dstaking/N2DRewards.sol";
import "https://github.com/net2devcrypto/n2dstaking/Collection.sol";

contract NFTStaking is Ownable, IERC721Receiver {

  struct vaultInfo {
        Collection nft;
        N2DRewards token;
        string name;
  }

  vaultInfo[] public VaultInfo;

  // struct to store a stake's token, owner, and earning values
  struct Stake {
    uint24 tokenId;
    uint48 timestamp;
    address owner;
  }

  uint256 public totalStaked;
  mapping(uint256 => Stake) public vault; 
  event NFTStaked(address owner, uint256 tokenId, uint256 value);
  event NFTUnstaked(address owner, uint256 tokenId, uint256 value);
  event Claimed(address owner, uint256 amount);

function addVault(
        Collection _nft,
        N2DRewards _token,
        string calldata _name
    ) public {
        VaultInfo.push(
            vaultInfo({
                nft: _nft,
                token: _token,
                name: _name
            })
        );
    }

  function stake(uint256 _pid, uint256[] calldata tokenIds) external {
    uint256 tokenId;
    totalStaked += tokenIds.length;
    vaultInfo storage vaultid = VaultInfo[_pid];
    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      require(vaultid.nft.ownerOf(tokenId) == msg.sender, "not your token");
      require(vault[tokenId].tokenId == 0, 'already staked');

      vaultid.nft.transferFrom(msg.sender, address(this), tokenId);
      emit NFTStaked(msg.sender, tokenId, block.timestamp);

      vault[tokenId] = Stake({
        owner: msg.sender,
        tokenId: uint24(tokenId),
        timestamp: uint48(block.timestamp)
      });
    }
  }

  function _unstakeMany(address account, uint256[] calldata tokenIds, uint256 _pid) internal {
    uint256 tokenId;
    totalStaked -= tokenIds.length;
    vaultInfo storage vaultid = VaultInfo[_pid];
    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      Stake memory staked = vault[tokenId];
      require(staked.owner == msg.sender, "not an owner");

      delete vault[tokenId];
      emit NFTUnstaked(account, tokenId, block.timestamp);
      vaultid.nft.transferFrom(address(this), account, tokenId);
    }
  }

  function claim(uint256[] calldata tokenIds, uint256 _pid) external {
      _claim(msg.sender, tokenIds, _pid, false);
  }

  function claimForAddress(address account, uint256[] calldata tokenIds, uint256 _pid) external {
      _claim(account, tokenIds, _pid, false);
  }

  function unstake(uint256[] calldata tokenIds, uint256 _pid) external {
      _claim(msg.sender, tokenIds, _pid, true);
  }

  function _claim(address account, uint256[] calldata tokenIds, uint256 _pid, bool _unstake) internal {
    uint256 tokenId;
    uint256 earned = 0;
    vaultInfo storage vaultid = VaultInfo[_pid];
    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      Stake memory staked = vault[tokenId];
      require(staked.owner == account, "not an owner");
      uint256 stakedAt = staked.timestamp;
      earned += 100000 ether * (block.timestamp - stakedAt) / 1 days;
      vault[tokenId] = Stake({
        owner: account,
        tokenId: uint24(tokenId),
        timestamp: uint48(block.timestamp)
      });

    }
    if (earned > 0) {
      earned = earned / 10;
      vaultid.token.mint(account, earned);
    }
    if (_unstake) {
      _unstakeMany(account, tokenIds, _pid);
    }
    emit Claimed(account, earned);
  }

  function earningInfo(uint256[] calldata tokenIds) external view returns (uint256[2] memory info) {
     uint256 tokenId;
     uint256 totalScore = 0;
     uint256 earned = 0;
      Stake memory staked = vault[tokenId];
      uint256 stakedAt = staked.timestamp;
      earned += 100000 ether * (block.timestamp - stakedAt) / 1 days;
    uint256 earnRatePerSecond = totalScore * 1 ether / 1 days;
    earnRatePerSecond = earnRatePerSecond / 100000;
    // earned, earnRatePerSecond
    return [earned, earnRatePerSecond];
  }

  // should never be used inside of transaction because of gas fee
  function balanceOf(address account,uint256 _pid) public view returns (uint256) {
    uint256 balance = 0;
    vaultInfo storage vaultid = VaultInfo[_pid];
    uint256 supply = vaultid.nft.totalSupply();
    for(uint i = 1; i <= supply; i++) {
      if (vault[i].owner == account) {
        balance += 1;
      }
    }
    return balance;
  }

  // should never be used inside of transaction because of gas fee
  function tokensOfOwner(address account, uint256 _pid) public view returns (uint256[] memory ownerTokens) {
    vaultInfo storage vaultid = VaultInfo[_pid];
    uint256 supply = vaultid.nft.totalSupply();
    uint256[] memory tmp = new uint256[](supply);

    uint256 index = 0;
    for(uint tokenId = 1; tokenId <= supply; tokenId++) {
      if (vault[tokenId].owner == account) {
        tmp[index] = vault[tokenId].tokenId;
        index +=1;
      }
    }

    uint256[] memory tokens = new uint256[](index);
    for(uint i = 0; i < index; i++) {
      tokens[i] = tmp[i];
    }

    return tokens;
  }

  function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
      require(from == address(0x0), "Cannot send nfts to Vault directly");
      return IERC721Receiver.onERC721Received.selector;
    }
  
}
