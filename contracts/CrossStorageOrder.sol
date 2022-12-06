// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12;

// Import this file to use console.log
import "./Xcm.sol";

contract CrossStorageOrder {
    // https://docs.astar.network/docs/xcm/building-with-xcm/xc-reserve-transfer/
    address internal constant SDN_ADDRESS = 0x0000000000000000000000000000000000000000;

    // https://github.com/AstarNetwork/Astar/blob/c358aa710fe6a498b4c56b0ddf1da322b21c524b/runtime/shiden/src/precompiles.rs#L92
    XCM xcmtransactor = XCM(0x0000000000000000000000000000000000005004);

    address payable public owner;
    // Since the evm address -> polkadot address convertor is decided by Astar,
    // we need know the corresponding polkadot address of this contract after the deployment.
    // Here is a helper page to do the convertor.
    // https://hoonsubin.github.io/evm-substrate-address-converter/
    // Then you can use subkey to get the AccountID32 and set it through this.set_address function.
    bytes32 public corr_address;

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
        // storage pallet index
        prefix[0] = bytes1(uint8(127));
        // storage call index
        prefix[1] = bytes1(uint8(0));
        // ipfs cid
        bytes memory cidBytes = toScaleString(cid);
        // ipfs file size
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
    function set_address(string memory addr) public {
        corr_address = bytes32(fromHex(addr));
    }

    function placeCrossChainOrder(string memory cid, uint64 size) public {
        uint256 parachain_id = 2012;
        uint256 pre_send_amount = 1000000000000000;
        // Transfer the SDN through XCMP
        address[] memory asset_id = new address[](1);
        asset_id[0] = SDN_ADDRESS;
        uint256[] memory asset_amount = new uint256[](1);
        asset_amount[0] = pre_send_amount;
        uint256 fee_index = 0;
        xcmtransactor.assets_reserve_transfer(asset_id, asset_amount, corr_address, false, parachain_id, fee_index);

        // Place cross chain storage order
        uint256 feeAmount = 8000;
        uint64 overallWeight = 8000000000;
        // cid: HiMoonbaseSC, size: 1024
        bytes memory call_data = buildCallBytes(cid, size);
        xcmtransactor.remote_transact(
            parachain_id,
            false,
            SDN_ADDRESS,
            feeAmount,
            call_data,
            overallWeight
        );
    }
}