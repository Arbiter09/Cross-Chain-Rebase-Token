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
    uint256 private constant PRECISION_FACTOR = 1e18;

    uint256 private s_interestRate = 5e10;
    // If s_userInterestRate[_user] was stored as 5e17, then multiplying it by timeElapsed would result in a much larger number
    // (5e17 * timeElapsed), requiring additional precision adjustments.
    // Instead, storing it as 5e10 ensures that when multiplied by timeElapsed, the result remains within the
    // correct scale without requiring an explicit division by PRECISION_FACTOR.

    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    ///////////////////////////////
    // Events                    //
    ///////////////////////////////
    event InterestRateSet(uint256 newInterestRate);

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
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The address to mint the tokens to
     * @dev This function mints the tokens to the user and updates their interest rate
     * @dev The interest rate is the global interest rate at the time of depositing
     * @param _amount The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) public {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn the user's tokens when they withdraw from the vault
     * @param _from The address to burn the tokens from
     * @dev This function burns the tokens from the user and updates their interest rate
     * @param _amount The amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * calaculate the balance for the user including the interest that has accrued since the last update
     * (principal balance) + some interest that has accrued since the last update
     * @param _user The address of the user
     * @return The balance of the user including the interest that has accrued since the last update
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user (the number of tokens that actually have been minted)
        // multiply the principle balance by the interest rate that has accumulated since the user deposited
        return (super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user)) / PRECISION_FACTOR;
        // divide by the precision factor to get the actual balance of the user
    }

    /**
     * @notice Calculate the interest that has accrued since the last update
     * @param _user The address of the user
     * @return linearInterest The interest that has accrued since the last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need to calculate the interest that has accrued since the last update
        // this is going to be a linear growth with time
        // 1. calculate the time that has passed since the last update
        // 2. calculate the amount of linear growth
        // principal amount(1 + (user interest rate*time elapsed))
        // deposit : 10 tokens
        // interest rate: 0.5 tokens per second
        // time elapsed: 2 seconds
        // 10 + (10 * 0.5 * 2) = 20 tokens
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    /**
     * @notice Update the user's interest rate and mint them the interest that has accrued since the last they interacted with the contract(eg mint,burn,tansfer)
     * @param _user The address of the user
     */
    function _mintAccruedInterest(address _user) internal {
        // (1) find their current balance of rebase tokens that have been minted to the user -> principal balance
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // (2) calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // (3) mint the difference between the current balance and the balance including interest
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // set the users last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        // call _mint to mint the tokens to user
        _mint(_user, balanceIncrease);
        // We are emitting an event in _mint function hence no need to emit an event here
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
