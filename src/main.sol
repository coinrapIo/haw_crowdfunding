pragma solidity ^0.5.12;

import "ds-token/token.sol";
import "ds-auth/auth.sol";


contract Main is DSAuth
{
    mapping(address => address) public _tkn_verifiers;
    mapping(address => uint) public _appoint_cnts;
    mapping(address => mapping(address => bool)) public _tkn_whl; 
    mapping(address => uint32[2]) public _appoint_ts_bewteen;

    event Appointment(address token, address user, uint amnt);
    event SetTokenParams(address token, address verifier, uint32 start, uint32 end);

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

    constructor() DSAuth() public {

    }

    function appoint(address token, address user, uint amnt, uint8 v, bytes32 r, bytes32 s) external tokenExists(token) betweenValidTimestamp(token)
    {
        
        require(_tkn_whl[token][user] == false, "already appoint!");

        bytes32 sig_hash = keccak256(abi.encodePacked(token, user, amnt));
        address recover_signer = recover_address(sig_hash, v, r, s);
        require(recover_signer == _tkn_verifiers[token], "must be signature by verifier of the token!");

        _tkn_whl[token][user] = true;
        _appoint_cnts[token] += 1;

        emit Appointment(token, user, amnt);

    }

    function setTokenParams(address token, address verifier, uint32[2] memory start_and_end) public auth {
        require(verifier != address(0x00), "the verifier is incorrect.");
        require(_tkn_verifiers[token] == address(0x00), "can't rewrite parameters of the token.");
        _tkn_verifiers[token] = verifier;
        
        if(start_and_end[0] > 0 && start_and_end[1] > 0)
        {
            _appoint_ts_bewteen[token] = start_and_end;
        }

        emit SetTokenParams(token, verifier, start_and_end[0], start_and_end[1]);

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