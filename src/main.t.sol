pragma solidity ^0.5.0;

import "ds-test/test.sol";
import "./main.sol";

contract MainTest is DSTest 
{

    function setUp() public {
        
    }

    function test1() public {
        address tk = address(0xE6333A5F9ec824434ba27BC5763509b3123353e4);
        address verifier = address(0x0b1D84d70bE774f531810c770675B82C566AC591);
        Main main = new Main();
        uint32[2] memory start_and_end = [uint32(1600604778), uint32(1600904778)];
        main.setTokenParams(tk, verifier, start_and_end);
        assertEq(main.getVerifier(tk), verifier);
        // assertEqDecimal(main.getValidTimestamp(tk)[0], start_and_end[0], 0);
        // assertEqDecimal(main.getValidTimestamp(tk)[1], start_and_end[1], 0);
    }

}