//SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./TimeFlowAccount.sol";
import "./interfaces/ITFAccount.sol";

contract TimeFlowNft is ERC721URIStorage{
    uint256 private _id;
    constructor()ERC721("Time Flow Genesis Token","TFGT"){}

    mapping(uint256=>address)public idToContractAddress;  //通过nftId得到合约地址

    //铸造nft
    function mintNft(string calldata _nftUrl)external returns(address hatTrick){
        hatTrick=address(
            new TimeFlowAccount{salt:keccak256(abi.encodePacked(
                address(this),
                block.chainid,
                _id,
                block.timestamp))}()
        );
        idToContractAddress[_id]=hatTrick;
        _safeMint(msg.sender,_id);
        _setTokenURI(_id,_nftUrl);
        ITFAccount(hatTrick).changeOwner1(msg.sender);
        require(getContractAccountOwner(_id)==msg.sender,"Owner not change");
        _id++;
        return hatTrick;
    }

    //存入ERC20代币
    function _saveERC20(address erc20TokenAddress,uint256 amount,uint256 _nftId)external{
        ITFAccount(idToContractAddress[_nftId]).saveERC20(erc20TokenAddress,amount);
    }

    //存入ERC721代币
    function _saveERC721(address erc721TokenAddress,uint256 saveNftId,uint256 _nftId)external{
        ITFAccount(idToContractAddress[_nftId]).saveERC721(erc721TokenAddress,saveNftId);
    }

    //存入ERC1155代币
    function _saveERC1155(address erc1155Address, uint256 _saveId, uint256 _amount, bytes memory _data,uint256 _nftId)external{
        ITFAccount(idToContractAddress[_nftId]).saveERC1155(erc1155Address,_saveId,_amount,_data);
    }

    //得到合约账户所有者
    function getContractAccountOwner(uint256 _nftId)public view returns(address){
        return ITFAccount(idToContractAddress[_nftId]).getThisOwner();
    }

    //重写转移函数
     function transferFrom(address from, address to, uint256 tokenId) public override(ERC721,IERC721) {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _transfer(from, to, tokenId);
        ITFAccount(idToContractAddress[tokenId]).changeOwner2(to);
        require(getContractAccountOwner(tokenId)==to,"Owner not change");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override(ERC721,IERC721) {
        safeTransferFrom(from, to, tokenId, "");
        ITFAccount(idToContractAddress[tokenId]).changeOwner2(to);
        require(getContractAccountOwner(tokenId)==to,"Owner not change");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override(ERC721,IERC721) {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
        ITFAccount(idToContractAddress[tokenId]).changeOwner2(to);
        require(getContractAccountOwner(tokenId)==to,"Owner not change");
    }
}