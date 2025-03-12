// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
* @title RebaseToken
* @author Jas shah
* @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
* @notice The interest rate in the smart contract can only decrease 
* @notice Each will user will have their own interest rate that is the global interest rate at the time of depositing.
*/
contract RebaseToken is ERC20 {
    ///////////////////////////////
    // Error Messages            //
    ///////////////////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    ////////////////////////////////////////
    // State Variable                    //
    ///////////////////////////////////////
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    ///////////////////////////////
    // Events                    //
    ///////////////////////////////
    event InterestRate(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    ////////////////////////////////////////
    // Functions                         //
    ///////////////////////////////////////
    /**
     * @notice Set the interest rate for the Rebase Token
     * @param _newInterestRate The new interest rate
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) public {
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRate(_newInterestRate);
    }

    function mint(address _to, uint256 _amount) public {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function _mintAccruedInterest(address _user) internal {
        // (1) find their current balance of rebase tokens that have been minted to the user
        // (2) calculate their current balance including any interest -> balanceOf
        // (3) mint the difference between the current balance and the balance including interest
        // call _mint to mint the tokens to user
        // set the users last updated timestamp

        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    ////////////////////////////////////////
    // Getter Functions                   //
    ///////////////////////////////////////

    /**
     * @notice Get the interest rate for ahat user
     * @param _user The user address to get interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
