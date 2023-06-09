// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../src/interfaces/ITreasury.sol";

contract Market is AccessControl {
    using SafeERC20 for ERC20;

    bytes32 public constant OPERATOR = keccak256("OPERATOR");

    IERC20 public currency;

    ITreasury public productTreasury;
    address public currencyTreasury;
    uint256 public marketsCount;

    struct MarketInfo {
        uint256 tgeRatio;
        uint256 start;// = block.timestamp;//1678896515;//block.timestamp; // Tuesday, 1 June 2021 г., 12:40:48 https://www.epochconverter.com/ 1678896515
        uint256 cliff;        
        uint256 duration; 
        uint256 slicePeriod;
        bool revocable;
        uint256 price; 
        uint256 minOrderSize;
        uint256 maxOrderSize;
        bool permisionLess; // true = igniring whitelist
        //mapping (address => bool) whitelist;
    }

    mapping(uint256 => MarketInfo) markets;

    constructor(address _currency, 
                address _productTreasury,
                address _currencyTreasury){
                    _setupRole(OPERATOR, msg.sender);
                    currency = IERC20(_currency);
                    productTreasury = ITreasury(_productTreasury);
                    currencyTreasury = _currencyTreasury;
                    //currency = IERC20(currency);
                    marketsCount = 0;

    }

    // @dev
    // Market selling a structural note contains treasury notes in a predetermined ratio 
    // 
    function deployMarket(uint256 _price,
                        uint256 _minOrderSize,
                        uint256 _maxOrderSize,
                        uint256 _tgeRatio, 
                        uint256 _start,
                        uint256 _cliff,
                        uint256 _duration,
                        uint256 _slicePeriod,
                        bool _revocable,
                        bool _permisionLess
                       ) public {
        require(hasRole(OPERATOR, msg.sender), "Caller is not an operator");

        markets[marketsCount] = MarketInfo(
            _tgeRatio,
            _start,
            _cliff,
            _duration,
            _slicePeriod,
            _revocable,
            _price,
            _minOrderSize,
            _maxOrderSize,
            _permisionLess
        );
        
        marketsCount += 1;

    }

    function migrateUser(uint256 _market, uint256 _amount, address _benefeciary) public {
        require(hasRole(OPERATOR, msg.sender), "Caller is not an operator");
        require(marketsCount > _market, "Incorect market");
        require(markets[_market].minOrderSize >= _amount && markets[_market].maxOrderSize <= _amount, "Min or max order size limit");

        (uint256 tgeAmount, uint256 vestingAmount) = calculateOrderSize(_market, _amount);
        productTreasury.withdrawTo(tgeAmount, _benefeciary);
        _migrateUser(_market, vestingAmount, _benefeciary);
    }

    function buy(uint256 _market, uint256 _amount, address _benefeciary) public {
        require(marketsCount > _market, "Incorect market");
        //require(markets[_market].minOrderSize >= _amount && markets[_market].maxOrderSize <= _amount, "Min or max order size limit");
        (uint256 tgeAmount, uint256 vestingAmount) = calculateOrderSize(_market, _amount);        
        currency.transferFrom(msg.sender, currencyTreasury, tgeAmount);
        
        productTreasury.withdrawTo(tgeAmount, _benefeciary);
        _migrateUser(_market, vestingAmount, _benefeciary);
    }

    function _migrateUser(uint256 _market, uint256 _amount, address _benefeciary) private {
        productTreasury.createVestingSchedule(_benefeciary, 
                                            markets[_market].start, 
                                            markets[_market].cliff, 
                                            markets[_market].duration, 
                                            markets[_market].slicePeriod, 
                                            markets[_market].revocable,
                                            _amount);
    }

    function calculateOrderSize(uint256 _market, uint256 _amount) public view returns(uint256 _tgeAmount, uint256 _vestingAmount) {
        require(marketsCount > _market, "Incorect market");

        _tgeAmount = _amount * markets[_market].tgeRatio / 1e5; // 100*3725/1000000
        _vestingAmount = _amount - _tgeAmount;

    }


    function calculateOrderPrice(uint256 _market, uint256 _amount) public view returns( uint256 _price ) {
        _price = _amount * markets[_market].price / 1e3; // price = price*1000, 0.01 = 10
    }

    function avaibleToClaim(uint256 _index, address _benefeciary) public view returns( uint256 _avaible ) {
        bytes32 vestingCalendarId = productTreasury.computeVestingScheduleIdForAddressAndIndex(_benefeciary, _index);
        _avaible = productTreasury.computeReleasableAmount(vestingCalendarId);
    }

    // @dev call getIndexCount, and claim in loop for all indexes
    function claimForIndex(uint256 _index) public {
            bytes32 vestingCalendarId = productTreasury.computeVestingScheduleIdForAddressAndIndex(msg.sender, _index);
            uint256 avaibleForClaim = productTreasury.computeReleasableAmount(vestingCalendarId);
            productTreasury.release(vestingCalendarId, avaibleForClaim);

    }

    // @dev Use carful - O(n) function
    function claim() public {
            uint256 vestingScheduleCount = productTreasury.getVestingSchedulesCountByBeneficiary(msg.sender);
            bytes32 vestingCalendarId;
            uint256 avaibleForClaim;
            for (uint256 calendarNumber = 0; calendarNumber < vestingScheduleCount; calendarNumber++) {
                vestingCalendarId = productTreasury.computeVestingScheduleIdForAddressAndIndex(address(this), calendarNumber);
                avaibleForClaim = productTreasury.computeReleasableAmount(vestingCalendarId);
                productTreasury.release(vestingCalendarId, avaibleForClaim);
            }


    }

    function getVestingScheduleForIndex(uint256 _index, address _benefeciary) public view returns(ITreasury.VestingSchedule memory) {
        return productTreasury.getVestingScheduleByAddressAndIndex(_benefeciary, _index);
    }

    // @dev Use careful - O(n) function
    function getVestingSchedules(address _benefeciary) public view returns(ITreasury.VestingSchedule[] memory){ 
        uint256 vestingScheduleCount = productTreasury.getVestingSchedulesCountByBeneficiary(_benefeciary);
        ITreasury.VestingSchedule[] memory vestingSchedules = new ITreasury.VestingSchedule[](vestingScheduleCount);
        for (uint256 calendarNumber = 0; calendarNumber < vestingScheduleCount; calendarNumber++) {
                vestingSchedules[calendarNumber] = productTreasury.getVestingScheduleByAddressAndIndex(_benefeciary, calendarNumber);
        }
        return vestingSchedules;
    }

    function getIndexCount(address _benefeciary) public view returns(uint256) {
        return productTreasury.getVestingSchedulesCountByBeneficiary(_benefeciary);
    }

    function getMarketInfo(uint256 _index) public view returns(MarketInfo memory) {
        return markets[_index];

    }


}

