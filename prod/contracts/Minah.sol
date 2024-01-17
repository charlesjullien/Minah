// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title A contract for Minah investment hub with ROI
/// @author https://github.com/charlesjullien

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



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
    //address contractOwner; // jln ... pas forcément besoin de la garder ecrite celle là.
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
        STABLECOIN = IERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359); // Native USDC contract address on polygon mainnet
        receiver = 0x314E53B23Ac8bf23b024af85fE50156894bcC42C; // Julien's address
        payer = 0x314E53B23Ac8bf23b024af85fE50156894bcC42C; // Julien's address
        // contractOwner = // = 0xaddresseDeJln
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

    /// @notice function to know how much to approve() on the USDC smart contract before releasing the amount to all investors.
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
        if (block.timestamp > (beginDate + 15768000) && state == InvestmentStatus.beforeFirstRelease) { // 182.5 days (6 months)
            distribute(9);
            state = InvestmentStatus.sixMonthsDone;
        }
        else if (block.timestamp > (beginDate + 26280000) && state == InvestmentStatus.sixMonthsDone) { // 304.1 days (10 months)
            distribute(8);
            state = InvestmentStatus.tenMonthsDone;
        }
        else if (block.timestamp > (beginDate + 36792000) && state == InvestmentStatus.tenMonthsDone) { // 425.8 days (14 months)
            distribute(8);
            state = InvestmentStatus.oneYearTwoMonthsDone;
        }
        else if (block.timestamp > (beginDate + 47304000) && state == InvestmentStatus.oneYearTwoMonthsDone) { // 547.5 days (18 months)
            distribute(8);
            state = InvestmentStatus.oneYearSixMonthsDone;
        }
        else if (block.timestamp > (beginDate + 57816000) && state == InvestmentStatus.oneYearSixMonthsDone) { // 669.1 days (22 months)
            distribute(8);
            state = InvestmentStatus.oneYearTenMonthsDone;
        }
        else if (block.timestamp > (beginDate + 68328000) && state == InvestmentStatus.oneYearTenMonthsDone) { // 790.8 days (26 months)
            distribute(8);
            state = InvestmentStatus.twoYearsTwoMonthsDone;
        }
        else if (block.timestamp > (beginDate + 78840000) && state == InvestmentStatus.twoYearsTwoMonthsDone) { // 912.5 days (30 months)
            distribute(8);
            state = InvestmentStatus.twoYearsSixMonthsDone;
        }
        else if (block.timestamp > (beginDate + 89352000) && state == InvestmentStatus.twoYearsSixMonthsDone) { // 1034.1 days (34 months)
            distribute(8);
            state = InvestmentStatus.twoYearsTenMonthsDone;
        }
        else if (block.timestamp > (beginDate + 99864000) && state == InvestmentStatus.twoYearsTenMonthsDone) { // 1155.8 days (38 months)
            distribute(8);
            state = InvestmentStatus.threeYearsTwoMonthsDone;
        }
        else if (block.timestamp > (beginDate + 110376000) && state == InvestmentStatus.threeYearsTwoMonthsDone) { // 1277.5 days (42 months)
            distribute(108);
            state = InvestmentStatus.threeYearsSixMonthsDone;

        }
        if (state == InvestmentStatus.threeYearsSixMonthsDone)
            state = InvestmentStatus.ended;
    }

    function seeClaimedAmount(address _investor) external view returns (uint256) {
        return (claimedAmount[_investor]);
    } 

    //////////////////////// TO DELETE FOR PROD ? ////////////////////////////////

    function setReceiver (address _receiver) external onlyOwner() {
        receiver = _receiver;
    }

    function setPayer (address _payer) external onlyOwner() {
        payer = _payer;
    }

}
