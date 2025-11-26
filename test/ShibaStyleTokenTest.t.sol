// test/TokenTest.t.sol
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/shib/ShibaStyleToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ShibaStyleTokenTest is Test {
    ShibaStyleToken public token;
    address public owner;
    address public user1;
    address public user2;
    MockERC20 public mockToken;

    function setUp() public {
        //设置随机测试地址
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy ShibaStyleToken
        token = new ShibaStyleToken{value: 0}(0x0000000000000000000000000000000000000000); // 虚拟路由器地址

        // Deploy MTKSI ERC20 token
        mockToken = new ERC20("MTKSI", "MTK-SI", 18);  //模拟意外发送其他代币的情形
        vm.prank(owner); //模拟 owner 地址执行后续操作,所有后续调用将被视为由 owner 发起。
        mockToken.mint(address(this), 1000 ether);
    }

    // ✅ 1. Constructor Test
    function testConstructor() public {
        assertEq(token.name(), "ShibaStyleToken");
        assertEq(token.symbol(), "SST");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 1_000_000_000 * 10**18);
        assertEq(token.owner(), owner);
        assertEq(token.balanceOf(owner), 1_000_000_000 * 10**18);
    }

    // ✅ 2. Transfer Test
    function testTransfer() public {
        vm.prank(owner);
        token.transfer(user1, 100 ether);

        assertEq(token.balanceOf(user1), 100 ether);
        assertEq(token.balanceOf(owner), 1_000_000_000 * 10**18 - 100 ether);
    }

    // ✅ 3. TransferFrom Test
    function testTransferFrom() public {
        vm.prank(owner);
        token.approve(user1, 100 ether);

        vm.prank(user1);
        token.transferFrom(owner, user2, 50 ether);

        assertEq(token.balanceOf(user2), 50 ether);
        assertEq(token.allowance(owner, user1), 50 ether);
    }

    // ✅ 4. Update Taxes Test
    function testUpdateTaxes() public {
        vm.prank(owner);
        token.updateTaxes(200, 400, 50);

        assertEq(token.buyTax(), 200);
        assertEq(token.sellTax(), 400);
        assertEq(token.transferTax(), 50);
    }

    // ✅ 5. Update Limits Test
    function testUpdateLimits() public {
        vm.prank(owner);
        token.updateLimits(1000000000, 2000000000, 60 minutes);

        assertEq(token.maxTxAmount(), 1000000000);
        assertEq(token.maxDailyAmount(), 2000000000);
        assertEq(token.tradeCooldown(), 60 minutes);
    }

    // ✅ 6. Exclude Address Test
    function testExcludeAddress() public {
        vm.prank(owner);
        token.excludeAddress(user1, true, true);

        assertEq(token.isExcludedFromFee(user1), true);
        assertEq(token.isExcludedFromLimit(user1), true);
    }

    // ✅ 7. Withdraw Stuck ETH Test
    function testWithdrawStuckETH() public {
        vm.prank(user1);
        (bool success,) = address(token).call{value: 1 ether}("");
        assertTrue(success);

        vm.prank(owner);
        token.withdrawStuckETH();

        assertEq(address(token).balance, 0);
    }

    // ✅ 8. Withdraw Stuck Tokens Test
    function testWithdrawStuckTokens() public {
        vm.prank(user1);
        mockToken.transfer(address(token), 100 ether);

        vm.prank(owner);
        token.withdrawStuckTokens(address(mockToken));

        assertEq(mockToken.balanceOf(owner), 100 ether);
    }
}