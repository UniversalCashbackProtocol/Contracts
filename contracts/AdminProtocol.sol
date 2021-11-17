// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./Store.sol";
import "./IUCPToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AdminProtocol is Ownable{
    uint private qtyStores;
    uint immutable private TAX_TOKEN = 103000;
    uint256 immutable private MINIMUN_TOKEN = 1 * 10 ** 18;   
    address private UCP;
    IERC20 private USDT;
    IUCPToken private token;
    
        
    struct LocalStore{
        uint id;
        address owner;
        string name;
        uint promotionsQty;
        address contractAddress;
    }
    
    struct Promotion{
        uint id;
        uint idStore;
        string name;
    }
    
    mapping(address => address) tokenPriceFeedMapping;
    mapping(uint => LocalStore) stores;
    mapping(address => mapping(uint => LocalStore)) storesByOwner;
    mapping(address => uint) amountAllowedToMint;

    constructor(address _USDT, address _token){
        qtyStores = 1;
        USDT = IERC20(_USDT);
        token = IUCPToken(_token);
    }

    function updateAddressesAllowedToMint(uint256 _amount, uint _idStore) external {   
        require(_amount > MINIMUN_TOKEN, "Amount must be greater or equal than one");  
        require(isValidStore(_idStore, msg.sender), "Only valid store can update");       
        LocalStore memory ls = stores[_idStore];
        require(ls.contractAddress == msg.sender, "Only valid store can call this function");
        token.setAddressAllowedToMint(msg.sender, _amount);        
    }

    function isValidStore(uint _idStore,address _storeContract) internal view returns(bool){
        require(_idStore > 0, "Id store must be greater than zero");
        LocalStore memory ls = stores[_idStore];
        if(ls.id > 0 && ls.contractAddress ==  _storeContract){
            return true;
        }else{
            return false;
        }
    }

    function updateAmountAllowedToMint(address _contract, uint256 _amount) external{
        amountAllowedToMint[_contract] = _amount;
    }        

    function createStore(string memory _name) public{
        Store cStore = new Store(msg.sender, qtyStores, _name, address(USDT), token, address(this));
        require(address(cStore) != address(0), "Contract must be deployed");
        LocalStore memory localStore = LocalStore(qtyStores, msg.sender, _name, 0, address(cStore));
        stores[qtyStores] = localStore;
        storesByOwner[msg.sender][qtyStores] = localStore;
        qtyStores++;
    }
        
    function addTokenToPriceFeed(address _token, address priceFeed)  public onlyOwner{
        require(_token != address(0) && priceFeed != address(0), "Must be valid addresses");
        tokenPriceFeedMapping[_token] =  priceFeed;        
    }
    
    function getTokenPriceByChainlink(address _token) public view returns (uint256) {
        address priceFeedAddress = tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return uint256(price);
    } 

    function calculateUSDPricePerToken(uint256 _amount, address _token) public view returns(uint256){
        uint256 totalToPay =  (((_amount / 10) / (10 ** (18 - 6))) * (getTokenPriceByChainlink(_token) / (10 ** 2))) / (10 ** 6); 
        return (totalToPay * TAX_TOKEN) / 10 ** 5;      
    }   

    function getInfoStore(uint _id) public view returns(LocalStore memory store){
        return stores[_id];
    }
    
    function getStoreByOwner(address _owner, uint256 _idStore) internal view returns(LocalStore memory store){
        return storesByOwner[_owner][_idStore];
    }

    function getAmountAllowedToMint(address _contract) public view returns(uint){
        return amountAllowedToMint[_contract];
    }
}