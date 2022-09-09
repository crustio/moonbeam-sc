// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12;

// Import this file to use console.log
import "./Xtokens.sol";
import "./XcmTransactor.sol";

contract CrossStorageOrder {
    // https://docs.moonbeam.network/builders/xcm/xc20/mintable-xc20/
    address internal constant CSM_ADDRESS = 0xffFfFFFf519811215E05eFA24830Eebe9c43aCD7;
    address internal constant MOVR_ADDRESS = 0x0000000000000000000000000000000000000802;

    XcmTransactorV2 xcmtransactor = XcmTransactorV2(0x000000000000000000000000000000000000080D);
    Xtokens xtokens = Xtokens(0x0000000000000000000000000000000000000804);

    address payable public owner;
    string public corr_address;

    constructor() {
        owner = payable(msg.sender);
    }

    modifier onlyOwner {
        require(
            msg.sender == owner,
            "Only owner can call this function"
        );
        _;
    }

    //https://docs.substrate.io/reference/scale-codec/
    function toBytes(uint64 x) internal pure returns (bytes memory) {
        bytes memory b = new bytes(8);
        for (uint i = 0; i < 8; i++) {
            b[i] = bytes1(uint8(x / (2**(8*i)))); 
        }
        return b;
    }

    //https://docs.substrate.io/reference/scale-codec/
    function toTruncBytes(uint64 x) internal pure returns (bytes memory) {
        bytes memory b = new bytes(8);
        uint len = 0;
        for (uint i = 0; i < 8; i++) {
            uint8 temp = uint8(x / (2**(8*i)));
            if(temp != 0) {
                b[i] = bytes1(temp); 
            } else {
                len = i;
                break;
            }
        }
        bytes memory rst = new bytes(len);
        for (uint i = 0; i < len; i++) {
            rst[i] = b[i];
        }
        return rst;
    }

    // Convert an hexadecimal character to their value
    function fromScaleChar(uint8 c) internal pure returns (uint8) {
        if (bytes1(c) >= bytes1('0') && bytes1(c) <= bytes1('9')) {
            return 48 + c - uint8(bytes1('0'));
        }
        if (bytes1(c) >= bytes1('a') && bytes1(c) <= bytes1('z')) {
            return 97 + c - uint8(bytes1('a'));
        }
        if (bytes1(c) >= bytes1('A') && bytes1(c) <= bytes1('Z')) {
            return 65 + c - uint8(bytes1('A'));
        }
        revert("fail");
    }

    // encode the string to bytes
    // following the scale format
    // format: len + content
    // a-z: 61->87
    // A-Z: 41->57
    // 0-9: 30->40
    function toScaleString(string memory s) internal pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        bytes memory len = toTruncBytes(uint64(ss.length*4));
        bytes memory content = new bytes(ss.length);
        for (uint i=0; i<ss.length; ++i) {
            content[i] = bytes1(fromScaleChar(uint8(ss[i])));
        }
        bytes memory rst = bytes.concat(len, content);
        return rst;
    }

    function buildCallBytes(string memory cid, uint64 size) internal pure returns (bytes memory) {
        bytes memory prefix = new bytes(2);
        prefix[0] = bytes1(uint8(127));
        prefix[1] = bytes1(uint8(0));
        bytes memory cidBytes = toScaleString(cid);
        bytes memory sizeBytes = toBytes(size);
        bytes memory rst = bytes.concat(prefix, cidBytes, sizeBytes);
        return rst;
    }

    // Convert an hexadecimal string to raw bytes
    function fromHex(string memory s) internal pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length%2 == 0); // length must be even
        bytes memory r = new bytes(ss.length/2);
        for (uint i=0; i<ss.length/2; ++i) {
            r[i] = bytes1(fromHexChar(uint8(ss[2*i])) * 16 +
                        fromHexChar(uint8(ss[2*i+1])));
        }
        return r;
    }

    // Convert an hexadecimal character to their value
    function fromHexChar(uint8 c) internal pure returns (uint8) {
        if (bytes1(c) >= bytes1('0') && bytes1(c) <= bytes1('9')) {
            return c - uint8(bytes1('0'));
        }
        if (bytes1(c) >= bytes1('a') && bytes1(c) <= bytes1('f')) {
            return 10 + c - uint8(bytes1('a'));
        }
        if (bytes1(c) >= bytes1('A') && bytes1(c) <= bytes1('F')) {
            return 10 + c - uint8(bytes1('A'));
        }
        revert("fail");
    }

    // set the correponding address on crust shadow of this contract
    // and transfer some MOVR to this contract
    function set_address(string memory addr) public {
        corr_address = addr;
    }

    function placeCrossChainOrder(string memory cid, uint64 size) public {
        // This should be calculated according to the settings of one storage order
        uint256 pre_send_amount = 1000100000;

        // https://docs.moonbeam.network/builders/xcm/xcm-transactor/
        bytes[] memory interior = new bytes[](2);
        interior[0] = fromHex("00000007DC"); // Selector Parachain, ID = 2012 (Crust Shadow Alpha)
        string memory concatAccountId32 = string.concat("01",corr_address,"00");
        interior[1] = fromHex(concatAccountId32); // AccountId32
        Xtokens.Multilocation memory derived_account = Xtokens.Multilocation(
            1, 
            interior
        );
        uint64 xtoken_weight = 5000000000;
        // Transfer the MOVR
        xtokens.transfer(MOVR_ADDRESS, pre_send_amount, derived_account, xtoken_weight);

        // Call the xcm transactor
        bytes[] memory chainDest = new bytes[](1);
        chainDest[0] = fromHex("00000007DC"); // Selector Parachain, ID = 2012 (Crust Shadow Alpha)
        XcmTransactorV2.Multilocation memory dest = XcmTransactorV2.Multilocation(
            1,
            chainDest
        );
        uint64 transactRequiredWeightAtMost = 4000000000;
        uint256 feeAmount = 8000;
        uint64 overallWeight = 8000000000;
        // cid: HiMoonbaseSC, size: 1024
        bytes memory call_data = buildCallBytes(cid, size);
        xcmtransactor.transactThroughSigned(
            dest,
            MOVR_ADDRESS,
            transactRequiredWeightAtMost,
            call_data,
            feeAmount,
            overallWeight
        );
    }
}