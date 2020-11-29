pragma solidity ^0.6.7;

import "ds-token/token.sol";
import "ds-auth/auth.sol";
import "./transferhelper.sol";

contract SimpleSale is DSAuth, DSMath
{
    mapping(address => uint) internal _tkn_sale_quantity;
    address public _default;
    
    // uint[2]{price, total_quantity}
    mapping(address => uint[2]) internal _tkn_sale_params;
    mapping(address => address) internal _tkn_owners;
    mapping(address => bool) public _tkn_open;
    mapping(address => uint) public balances;

    event SetSaleParams(address indexed token, address owner, uint price, uint quantity);
    event CrowdSell(address indexed token, uint price, uint volume, address user);
    event SetTokenOpen(address indexed token, bool open);
    event Claim(address indexed receiver, uint amount);

    modifier tokenExists(address token)
    {
        require(_tkn_owners[token] != address(0x00), "the token not exists!");
        _;
    }

    modifier tokenOpen(address token)
    {
        require(_tkn_open[token], "the token is not open for sale!");
        _;
    }

    constructor() DSAuth() payable public 
    {

    }

    receive() payable external
    {
        crowdsell(_default);
    }

    function claim(uint amount) public 
    {
        require(balances[msg.sender] > 0 && balances[msg.sender] >= amount, "The balance is insufficient.");
        
        balances[msg.sender] = sub(balances[msg.sender], amount);
        TransferHelper.safeTransferETH(msg.sender,amount);
        
        emit Claim(msg.sender, amount);
    }

    function crowdsell(address token) public payable tokenExists(token) tokenOpen(token)
    {
        sell(token, msg.value, msg.sender);
        emit CrowdSell(token, _tkn_sale_params[token][0], msg.value, msg.sender);
    }

    function sell(address token, uint msgValue, address msgSender) private
    {
        require(_tkn_owners[token] != address(0x00) && _tkn_sale_params[token][0] > 0, "Not yet started, stay tuned.");
        address tokenOwner = _tkn_owners[token];
        uint price = _tkn_sale_params[token][0];
        uint total_quantity = _tkn_sale_params[token][1];
        uint amount = wmul(msgValue, price);

        require(add(_tkn_sale_quantity[token],amount) <= total_quantity, "sold out!");
        require(DSToken(token).allowance(tokenOwner, address(this)) >= amount, "reach to uplimit of allowance.");
        TransferHelper.safeTransferFrom(token,tokenOwner, msgSender, amount);
        _tkn_sale_quantity[token] = add(_tkn_sale_quantity[token], amount);
        balances[tokenOwner] = add(balances[tokenOwner], msgValue);
    }

    function setSaleParams(address token, address owner, uint[2] memory price_uplimit, bool isDefault) public auth{
        require(token != address(0x00), "incorrect token address.");
        require(owner != address(0x00), "incorrect token owner.");
        
        if(_tkn_owners[token] == address(0x00))
        {
            _tkn_owners[token] = owner;
        }
        if(isDefault)
        {
            _default = token;
        }
        
        require(price_uplimit.length == 2 && price_uplimit[0] > 0 && price_uplimit[1] > 0, "They must be correct(price, sale quantity).");
        
        require(DSToken(token).allowance(owner, address(this)) >= price_uplimit[1], "makesure allowance enough!");
        _tkn_sale_params[token] = price_uplimit;
        
        emit SetSaleParams(token, owner, price_uplimit[0], price_uplimit[1]);
    }

    function setTokenOpen(address token, bool isOpen) public auth tokenExists(token)
    {
        _tkn_open[token] = isOpen;
        emit SetTokenOpen(token, isOpen);
    }

    function getSaleParams(address token) public view returns (uint[2] memory)
    {
        return _tkn_sale_params[token];
    }

    function getTokenOwner(address token) public view returns (address)
    {
        return _tkn_owners[token];
    }

    function getSaleQuantity(address token) public view returns (uint)
    {
        return _tkn_sale_quantity[token];
    }

}