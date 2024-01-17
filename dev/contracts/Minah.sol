// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title A contract for Minah investment hub with ROI
/// @author https://github.com/charlesjullien

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



// ==> TESTS <== //
/*
Call les fonctions en tant que non onwner
Try de mint si on a pas assez d'USDC
Try de mint si on est pas registred en tant que verified user
Try de mint quand c'est pas la bonne phase pour ca.
Try de mint et verifier si le user s'ajoute bien dans le investorsArray
Try de mint - que la limite des 150
Try de mint + que la limite des 150
Try de mint + que la total supply
verifier l'etat des variables sensibles avant et après le call à startChronometer()
essayer d'appeler 2 fois startChronometer()




*/


contract Minah is ERC1155, Ownable {

    IERC20 public STABLECOIN;

    uint256 public constant ITEM_ID = 0;
    uint256 public constant TOTAL_SUPPLY = 4500;
    uint256 public constant PRICE = 10;
    string public constant NAME = "Minah";
    string public constant SYMBOL = "MNH";

    uint256 public currentSupply;
    uint256 public beginDate;
    uint256 public amountToReleaseForCurrentStage;
    address receiver; // frblocks adress
    address payer; // frblocks adress
    address[] public investorsArray;
    bool countdownStart;
    mapping (address => bool) public investors; //public ?
    mapping (address => uint256) public claimedAmount;

    /// @notice All the workflow stages in logic ascending order for the contract workflow   
    enum InvestmentStatus {
        buyingPhase,
        beforeFirstRelease,
        sixMonthsDone,
        tenMonthsDone,
        oneYearTwoMonthsDone,
        oneYearSixMonthsDone,
        oneYearTenMonthsDone,
        twoYearsTwoMonthsDone,
        twoYearsSixMonthsDone,
        twoYearsTenMonthsDone,
        threeYearsTwoMonthsDone,
        threeYearsSixMonthsDone,
        ended
    }

    InvestmentStatus public state = InvestmentStatus.buyingPhase;
    
    /// @notice Inititialyze the contract as an ERC1155 and Ownable for the contract builder address.
    constructor() ERC1155("") Ownable() {
        currentSupply = 0;
        STABLECOIN = IERC20(0x0FA8781a83E46826621b3BC094Ea2A0212e71B23); //USDC contract address on polygon mumbai.
        receiver = 0x314E53B23Ac8bf23b024af85fE50156894bcC42C; // Julien's address
        payer = 0x314E53B23Ac8bf23b024af85fE50156894bcC42C; // Julien's address
        countdownStart = false;
        beginDate = 0;
        transferOwnership(0x314E53B23Ac8bf23b024af85fE50156894bcC42C); // Julien's address
    }

    /// @notice Use this function to change the current stablecoin contract address in case the current one is depegged 
    /// @param _newStablecoinInterface : the new stablecoin address to replace the old one in the IERC20 'STABLECOIN' interface
    function setNewStablecoinInterface(address _newStablecoinInterface) public onlyOwner {
        STABLECOIN = IERC20(_newStablecoinInterface);
    }

    /// @notice Use this function to change the current URI storing the NFT metadatas.
    /// @param newuri : the new Uri to replace the old one.
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    /// @notice function called from the backend when a user creates a profile on the Minah platform 
    /// @param _newInvestor : the fireblocks address generated for the new user. To store in the backend.
    function createInvestor (address _newInvestor) public onlyOwner {
        investors[_newInvestor] = true;
    }

    /// @notice function to mint _amount NFTs, and get registred in the investors Array for remuneration later
    /// @param _user : the address generated during profile creation for the user connected at the moment trying to buy NFTs.
    /// @param _amount : the amount of NFTs the user wants to buy.
    function mint(address _user, uint256 _amount) public { // ajouter onlyOwner ? // CHECK WITH JULIEN ADD ONLYOWNER 
        uint256 USD_amount = PRICE * _amount * 10**6;
        require(state == InvestmentStatus.buyingPhase, "Buying phase is now over.");
        require(investors[_user] == true, "_user is not part of the Minah verified investors.");
        require(balanceOf(_user, 0) + _amount >= 40 && balanceOf(_user, 0) + _amount <= 150, "Total owned items must be greater than or equal to 40 and less than or equal to 150.");
        require(STABLECOIN.balanceOf(_user) >= (PRICE * _amount), "PRICE is 10 USD per NFT"); //add decimals
        require((currentSupply + _amount) <= TOTAL_SUPPLY, "Total and maximum supply is 4500 items.");
        require(STABLECOIN.transferFrom(_user, receiver, USD_amount), "transferFrom failed"); // call "approve(thisContractAddress, _amount * 10**6)" function in the frontend before this function
        _mint(_user, ITEM_ID, _amount, "");
        currentSupply += _amount;
        if (balanceOf(_user, 0) - _amount == 0)
            investorsArray.push(_user);
    }


    /// @notice function called by the contract Owner to begin the return on investment chronometer and stage ("beforeFirstRelease"), and mint the rest of NFTs.
    function startChronometer() external onlyOwner {
        require(countdownStart == false && beginDate == 0, "You have already started the chronometer"); 
        beginDate = block.timestamp;
        countdownStart = true;
        state = InvestmentStatus.beforeFirstRelease;
        _mint(owner(), ITEM_ID, (TOTAL_SUPPLY - currentSupply), "");
        currentSupply = TOTAL_SUPPLY;
    }

    /// @notice function to know how much to approve() on the STABLECOIN smart contract before releasing the amount to all investors.
    /// @param percent : the percentage of ROI that is going to be released on next remuneration. 
    /// @return the amount to release for the next remuneration
    function calculateAmountToRelease (uint256 percent) public onlyOwner view returns (uint256) {
        uint256 amountToRelease = 0;
        uint256 i = 0;
        percent = percent * 10**6; 
        while (i < investorsArray.length) {
            amountToRelease += (balanceOf(investorsArray[i], 0) * percent / 100) * PRICE;
            i++;
        }
        return amountToRelease;
    }

    /// @notice the function called from releaseDistribution() and used to distribute to investors what they earned during the current period/stage.
    /// @param percent : the percentage of ROI that is going to be released for that stage.
    function distribute (uint256 percent) private onlyOwner {
        require (state != InvestmentStatus.ended, "The investing and distribution phases are over.");
        amountToReleaseForCurrentStage = calculateAmountToRelease(percent);
        percent = percent * 10**6;
        uint256 verifyReleasedAmount = 0;
        uint256 i = 0;
        while (i < investorsArray.length) {
            require(STABLECOIN.transferFrom(payer, investorsArray[i], ((balanceOf(investorsArray[i], 0) * percent / 100) * PRICE)), "transferFrom failed"); // call usdc approve() function before of course.
            claimedAmount[investorsArray[i]] += (balanceOf(investorsArray[i], 0) * percent / 100) * PRICE;
            verifyReleasedAmount += (balanceOf(investorsArray[i], 0) * percent / 100) * PRICE;
            i++;
        }
        require(verifyReleasedAmount == amountToReleaseForCurrentStage, "There has been an issue with the distribution.");
    }

    /// @notice this function needs to be called by the owner at the end of every distribution period/stage to trigger the current release and next stage. 
    function releaseDistribution () external onlyOwner {
        require(countdownStart == true, "Countdown has not started yet.");
        if (block.timestamp > (beginDate + 86400) && state == InvestmentStatus.beforeFirstRelease) { // 1 day
            distribute(9);
            state = InvestmentStatus.sixMonthsDone;
        }
        else if (block.timestamp > (beginDate + 144000) && state == InvestmentStatus.sixMonthsDone) { // 1.66 days
            distribute(8);
            state = InvestmentStatus.tenMonthsDone;
        }
        else if (block.timestamp > (beginDate + 201600) && state == InvestmentStatus.tenMonthsDone) { // 2.33 days
            distribute(8);
            state = InvestmentStatus.oneYearTwoMonthsDone;
        }
        else if (block.timestamp > (beginDate + 259200) && state == InvestmentStatus.oneYearTwoMonthsDone) { // 3 days
            distribute(8);
            state = InvestmentStatus.oneYearSixMonthsDone;
        }
        else if (block.timestamp > (beginDate + 316800) && state == InvestmentStatus.oneYearSixMonthsDone) { // 3.66 days
            distribute(8);
            state = InvestmentStatus.oneYearTenMonthsDone;
        }
        else if (block.timestamp > (beginDate + 374400) && state == InvestmentStatus.oneYearTenMonthsDone) { // 4.33 days
            distribute(8);
            state = InvestmentStatus.twoYearsTwoMonthsDone;
        }
        else if (block.timestamp > (beginDate + 432000) && state == InvestmentStatus.twoYearsTwoMonthsDone) { // 5 days
            distribute(8);
            state = InvestmentStatus.twoYearsSixMonthsDone;
        }
        else if (block.timestamp > (beginDate + 489600) && state == InvestmentStatus.twoYearsSixMonthsDone) { // 5.66 days
            distribute(8);
            state = InvestmentStatus.twoYearsTenMonthsDone;
        }
        else if (block.timestamp > (beginDate + 547200) && state == InvestmentStatus.twoYearsTenMonthsDone) { // 6.33 days
            distribute(8);
            state = InvestmentStatus.threeYearsTwoMonthsDone;
        }
        else if (block.timestamp > (beginDate + 604800) && state == InvestmentStatus.threeYearsTwoMonthsDone) { // 7 days
            distribute(108);
            state = InvestmentStatus.threeYearsSixMonthsDone;

        }
        if (state == InvestmentStatus.threeYearsSixMonthsDone)
            state = InvestmentStatus.ended;
    }

    function seeClaimedAmount(address _investor) external view returns (uint256) {
        return (claimedAmount[_investor]);
    } 

    //////////////////////// TO DELETE FOR PROD ////////////////////////////////

    function setReceiver (address _receiver) external onlyOwner() {
        receiver = _receiver;
    }

    function setPayer (address _payer) external onlyOwner() {
        payer = _payer;
    }

}
