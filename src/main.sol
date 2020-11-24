pragma solidity ^0.6.7;

import "ds-token/token.sol";
import "ds-auth/auth.sol";


contract Main is DSAuth, DSMath
{
    mapping(address => address) public _tkn_verifiers;
    mapping(address => uint) public _tkn_sale_quantity;
    mapping(address => mapping(address => bool)) public _tkn_whl; 
    mapping(address => uint32[2]) public _appoint_ts_bewteen;
    // uint[3]{price, rebate_rate, total_quantity}
    mapping(address => uint[3]) public _tkn_sale_params;
    mapping(address => address) public _tkn_owners;
    mapping(address => uint) public balances;

    event Appointment(address indexed token, address user, uint amnt);
    event SetTokenParams(address indexed token, address verifier, uint32 start, uint32 end);
    event SetSaleParams(address indexed token, address owner, uint price, uint quantity, uint rebate_rate);
    event PreSale(address indexed token, uint price, uint volume, address user, address inviter, uint rebate);
    event CrowdSell(address indexed token, uint price, uint volume, address user, address inviter, uint rebate);
    event Claim(address indexed receiver, uint amount);

    modifier tokenExists(address token)
    {
        require(_tkn_verifiers[token] != address(0x00), "the token not exists!");
        _;
    }

    modifier betweenValidTimestamp(address token)
    {
        uint32[2] memory start_and_end = _appoint_ts_bewteen[token];
        if(start_and_end[0] > 0 && start_and_end[1] > 0)
        {
            require(block.timestamp >= start_and_end[0] &&  block.timestamp <= start_and_end[1], "out of valid timestamp.");
        }
        _;
    }

    function verifySig(address token, address inviter, uint8 v, bytes32 r, bytes32 s) private view
    { 
        bytes32 sig_hash = keccak256(abi.encodePacked(token, msg.sender, inviter));
        address recover_signer = recover_address(sig_hash, v, r, s);
        require(recover_signer == _tkn_verifiers[token], "must be signature by verifier of the token!");
        
    }

    constructor() DSAuth() payable public 
    {

    }

    function claim(uint amount) public 
    {
        require(balances[msg.sender] > 0, "There is no award.");
        require(balances[msg.sender] >= amount, "The balance is insufficient.");
        
        balances[msg.sender] -= amount;
        uint userBalance = msg.sender.balance;
        msg.sender.transfer(amount);
        
        require(msg.sender.balance - userBalance == amount, "reentry!");
        
        emit Claim(msg.sender, amount);
    }

    function presale(address token, address inviter, uint8 v, bytes32 r, bytes32 s) public payable tokenExists(token)
    {
        require(_tkn_whl[token][msg.sender], "please appoint first!");
        
        verifySig(token, inviter, v, r, s);
        uint rebate = sell(token, msg.value, msg.sender, inviter);

        emit PreSale(token, _tkn_sale_params[token][0], msg.value, msg.sender, inviter, rebate);
    }

    function crowdsell(address token, address inviter, uint8 v, bytes32 r, bytes32 s) public payable tokenExists(token)
    {
        verifySig(token, inviter, v, r, s);
        uint rebate = sell(token, msg.value, msg.sender, inviter);

        emit CrowdSell(token, _tkn_sale_params[token][0], msg.value, msg.sender, inviter, rebate);
    }

    function sell(address token, uint msgValue, address msgSender, address inviter) private returns(uint rebate)
    {
        require(_tkn_owners[token] != address(0x00) && _tkn_sale_params[token][0] > 0, "Not yet started, stay tuned.");
        address token_owner = _tkn_owners[token];
        uint price = _tkn_sale_params[token][0];
        uint rebate_rate = _tkn_sale_params[token][1];
        uint total_quantity = _tkn_sale_params[token][2];
        uint amount = mul(price, msgValue);

        require(_tkn_sale_quantity[token] + amount <= total_quantity, "sold out!");
        require(DSToken(token).allowance(token_owner, address(this)) >= amount, "reach to uplimit of allowance.");
        DSToken(token).transferFrom(token_owner, msgSender, amount);
        _tkn_sale_quantity[token] += amount;
        rebate = 0;
        if(inviter != address(0x00) && rebate_rate > 0)
        {
            rebate = wdiv(wmul(msgValue, rebate), 1e18);
            if(rebate > 0)
            {
                balances[inviter] += rebate;
            }
        }
        balances[token_owner] += msgValue - rebate;
    }

    function appoint(address token, uint amnt, uint8 v, bytes32 r, bytes32 s) public tokenExists(token) betweenValidTimestamp(token)
    {        
        require(_tkn_whl[token][msg.sender] == false, "already appoint!");

        bytes32 sig_hash = keccak256(abi.encodePacked(token, msg.sender, amnt));
        address recover_signer = recover_address(sig_hash, v, r, s);
        require(recover_signer == _tkn_verifiers[token], "must be signature by verifier of the token!");

        _tkn_whl[token][msg.sender] = true;

        emit Appointment(token, msg.sender, amnt);

    }

    function setTokenParams(address token, address verifier, uint32[2] memory start_and_end) public auth {
        require(token != address(0x00), "incorrect token address");
        require(verifier != address(0x00), "the verifier is incorrect.");
        require(_tkn_verifiers[token] == address(0x00), "can't rewrite parameters of the token.");
        _tkn_verifiers[token] = verifier;
        
        if(start_and_end[0] > 0 && start_and_end[1] > 0)
        {
            _appoint_ts_bewteen[token] = start_and_end;
        }

        emit SetTokenParams(token, verifier, start_and_end[0], start_and_end[1]);
    }

    function setSaleParams(address token, address owner, uint[3] memory price_uplimit_rebate) public auth{
        require(token != address(0x00), "incorrect token address.");
        require(owner != address(0x00), "incorrect token owner.");
        require(price_uplimit_rebate.length == 3 && price_uplimit_rebate[0] > 0 && price_uplimit_rebate[0] > 0, "They must be correct(price, sale quantity, rebate).");
        DSToken(token).approve(owner, price_uplimit_rebate[1]);
        
        emit SetSaleParams(token, owner, price_uplimit_rebate[0], price_uplimit_rebate[1], price_uplimit_rebate[2]);
    }

    function hasAppoint(address token) public view returns (bool)
    {
        return _tkn_whl[token][msg.sender];
    }

    function getVerifier(address token) public view returns(address)
    {
        return _tkn_verifiers[token];
    }

    function getValidTimestamp(address token) public view returns(uint32[2] memory)
    {
        return _appoint_ts_bewteen[token];
    }


    function recover_address(
        bytes32 h,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address){
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixed_hash = keccak256(abi.encodePacked(prefix, h));
        return ecrecover(prefixed_hash, v, r, s); 
    }

}