//SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IERC6551.sol";

//支持本地代币、erc20、erc721、erc1155代币存储与提取
contract TimeFlowAccount is Multicall, ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 private openTime;
    uint256 private id = 1;
    address private contractOwner; //合约所有者

    constructor() {
        contractOwner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Not owner");
        _;
    }

    modifier onlyContractOwner() {
        require(tx.origin == contractOwner, "Not owner");
        _;
    }
    mapping(address => uint256) private userSaveLocalAmount;

    //设置时间,使用multicall
    function setTime() external onlyOwner {
        openTime = block.timestamp;
    }

    //合约转移所有权
    function changeOwner1(address newOwner) public onlyOwner {
        contractOwner = newOwner;
    }

    //用户转移所有权,使用multicall与主合约NFT转移绑定在一起
    function changeOwner2(address newOwner) public onlyContractOwner {
        require(openTime == block.timestamp, "Time error"); //time是否超过
        contractOwner = newOwner;
    }

    //存入ERC20代币
    function saveERC20(address erc20TokenAddress, uint256 amount)
        external
        nonReentrant
    {
        uint256 beforeBalance = getERC20Balance(
            erc20TokenAddress,
            address(this)
        );
        IERC20(erc20TokenAddress).safeTransferFrom(
            contractOwner,
            address(this),
            amount
        );
        uint256 laterBalance = getERC20Balance(
            erc20TokenAddress,
            address(this)
        );
        require(laterBalance - beforeBalance == amount, "Save ERC20 error"); //检查余额是否变化
    }

    //存入gas代币
    function saveLocalToken(uint256 _amount) external payable nonReentrant {
        require(msg.value >= _amount); //持有的本地代币需要>=本身持有的代币
        userSaveLocalAmount[msg.sender] += _amount;
    }

    //提取代币
    function withdrawLocalToken(uint256 _amount) external payable onlyOwner {
        require(address(this).balance >= _amount);
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Withdraw error");
        userSaveLocalAmount[msg.sender] -= _amount;
    }

    //提取ERC20代币
    function withdrawERC20(
        address erc20TokenAddress,
        address to,
        uint256 amount
    ) external onlyOwner {
        uint256 beforeBalance = getERC20Balance(
            erc20TokenAddress,
            address(this)
        );
        uint256 toBeforeBalance = getERC20Balance(erc20TokenAddress, to);
        IERC20(erc20TokenAddress).safeTransferFrom(address(this), to, amount);
        uint256 laterBalance = getERC20Balance(
            erc20TokenAddress,
            address(this)
        );
        uint256 toLaterBalance = getERC20Balance(erc20TokenAddress, to);
        require(
            laterBalance - beforeBalance == amount &&
                toLaterBalance - toBeforeBalance == amount,
            "Withdraw ERC20 error"
        ); //检查余额是否变化
    }

    //存入ERC721代币
    function saveERC721(address erc721TokenAddress, uint256 nftId)
        external
        nonReentrant
    {
        uint256 beforeBalance = getERC721Balance(
            erc721TokenAddress,
            address(this)
        );
        IERC721(erc721TokenAddress).transferFrom(
            contractOwner,
            address(this),
            nftId
        );
        uint256 laterBalance = getERC20Balance(
            erc721TokenAddress,
            address(this)
        );
        require(laterBalance - beforeBalance == 1, "Save ERC721 error"); //检查余额是否变化
    }

    //提取ERC721代币
    function withdrawERC721(
        address erc721TokenAddress,
        address to,
        uint256 nftId
    ) external onlyOwner {
        uint256 beforeBalance = getERC721Balance(
            erc721TokenAddress,
            address(this)
        );
        IERC721(erc721TokenAddress).transferFrom(address(this), to, nftId);
        uint256 laterBalance = getERC20Balance(
            erc721TokenAddress,
            address(this)
        );
        require(laterBalance - beforeBalance == 1, "Withdraw ERC721 error"); //检查余额是否变化
        require(
            getERC721Owner(erc721TokenAddress, nftId) == to,
            "Receiver error"
        ); // 检查to有没有收到
    }

    //存入ERC1155代币
    function saveERC1155(address erc1155Address, uint256 _id, uint256 _amount, bytes memory _data)external{
        uint256 beforeBalance=getERC1155Balance(erc1155Address,address(this),_id);
        IERC1155(erc1155Address).safeTransferFrom(msg.sender,address(this),_id,_amount,_data);
        uint256 afterBalance=getERC1155Balance(erc1155Address,address(this),_id);
        require(afterBalance-beforeBalance==_amount,"Save Erc1155 error");
    }

    //提取ERC1155代币
    function withdrawERC1155(address erc1155Address, uint256 _id, uint256 _amount, bytes memory _data)external{
        uint256 beforeBalance=getERC1155Balance(erc1155Address,address(this),_id);
        IERC1155(erc1155Address).safeTransferFrom(address(this),msg.sender,_id,_amount,_data);
        uint256 afterBalance=getERC1155Balance(erc1155Address,address(this),_id);
        require(beforeBalance-afterBalance==_amount,"Withdraw Erc1155 error");
    }

    //查看当前地址余额是否变动
    function getERC20Balance(address erc20TokenAddress, address checkAddress)
        public
        view
        returns (uint256)
    {
        return IERC20(erc20TokenAddress).balanceOf(checkAddress);
    }

    //查看当前地址ERC721余额是否变动
    function getERC721Balance(address erc721TokenAddress, address checkAddress)
        public
        view
        returns (uint256)
    {
        return IERC721(erc721TokenAddress).balanceOf(checkAddress);
    }

    //ERC721所有者
    function getERC721Owner(address erc721TokenAddress, uint256 nftId)
        public
        view
        returns (address)
    {
        return IERC721(erc721TokenAddress).ownerOf(nftId);
    }

    //查看当前ERC1155数量变化
    function getERC1155Balance(address erc1155Address,address _account, uint256 _id)public view returns(uint256){
        return IERC1155(erc1155Address).balanceOf(_account,_id);
    }

    //返回当前所有者
    function getThisOwner() external view returns (address) {
        return contractOwner;
    }

}
