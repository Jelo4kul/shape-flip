// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IShapeFlip.sol";
import "hardhat/console.sol";

//TODO: Update variables to fit into the model of the game

/** 
 * @title Boosters
 * @dev NFTs that gives a multiplier effect on the shapeflip game
 */
contract Boosters is ERC721, Ownable {

    IShapeFlip shapeFlip;
    uint64 private currentTokenId;

    struct BoosterType {
        string name;
        uint16 revealMultiplier;
        uint8 unfreezeMultiplier;
        uint16 shapeMultiplier;
        uint8 delayExemptions;
    }

   // mapping(uint16 => BoosterType) boosterTypes;
  //  mapping(uint64 => BoosterType) boosterOwners;
    mapping(uint64 => BoosterType) private boosterCategory;
    mapping(address => uint64) previousTimesWon;
    uint16 private boosterCount;
    uint16 boosterLimit = 8;
    BoosterType[7] boosterTypes;

    constructor() ERC721("Boosters", "Boosters") {
        //shapeFlip(address);
        BoosterType memory novice = BoosterType({name: 'novice', revealMultiplier: 1, unfreezeMultiplier: 0, shapeMultiplier: 0, delayExemptions: 0});
        BoosterType memory graduate = BoosterType({name: 'graduate', revealMultiplier: 2, unfreezeMultiplier: 0, shapeMultiplier: 0, delayExemptions: 0});
        BoosterType memory challenger = BoosterType({name: 'challenger', revealMultiplier: 2, unfreezeMultiplier: 2, shapeMultiplier: 0, delayExemptions: 2});
        BoosterType memory professional = BoosterType({name: 'professional', revealMultiplier: 2, unfreezeMultiplier: 4, shapeMultiplier: 0, delayExemptions: 4});
        BoosterType memory expert = BoosterType({name: 'expert', revealMultiplier: 2, unfreezeMultiplier: 4, shapeMultiplier: 2, delayExemptions: 4});
        BoosterType memory master = BoosterType({name: 'master', revealMultiplier: 3, unfreezeMultiplier: 4, shapeMultiplier: 2, delayExemptions: 4});
        BoosterType memory flipKing = BoosterType({name: 'flipKing', revealMultiplier: 3, unfreezeMultiplier: 6, shapeMultiplier: 2, delayExemptions: 6});

        boosterTypes[0] = novice;
        boosterTypes[1] = graduate;
        boosterTypes[2] = challenger;
        boosterTypes[3] = professional;
        boosterTypes[4] = expert;
        boosterTypes[5] = master;
        boosterTypes[6] = flipKing;

        //check if the above or something like this below is more gas effective
        //boosterTypes[0] = BoosterType({name: 'novice', revealMultiplier: 1, unfreezeMultiplier: 0, shapeMultiplier: 0, delayExemptions: 0});
    }

    function setShapeFlip(address _shapeFlip) external onlyOwner {
           shapeFlip =  IShapeFlip(_shapeFlip);
    }

    //TODO: Only ShapeFlip contract should be able to call this
    //TODO: should be only to mint once per round
    function mintBooster() external {
        //(uint64 _score, address _winner) = shapeFlip.getRoundWinner(_round);
     //   if(_winner == msg.sender) {
            ++currentTokenId;
            uint64 timesWon = shapeFlip.getTimesWon(msg.sender);
            require(timesWon > previousTimesWon[msg.sender], "Haven't won any new round");
            boosterCategory[currentTokenId] = boosterTypes[uint16(timesWon) % boosterLimit];
            previousTimesWon[msg.sender] = timesWon;
            _mint(msg.sender, currentTokenId);
       // }
    }

    //TODO: the attribute of this should map with a user's booster/shapeFilp timeswon
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
       // uint16 boosterType = boosterCategory[uint64(_tokenId)];
    }

    function setBoosterLimit(uint16 _boosterLimit)  external onlyOwner {
        boosterLimit = _boosterLimit;
    }

   // function getBoosterCategory(uint64 _tokenId) external returns(uint16) {
   //     return boosterCategory[_tokenId];
  //  }

    function getBoosterTypes(uint64 _tokenId) external view returns(string memory name, uint16 revealMultiplier, uint8 unfreezeMultiplier, uint16 shapeMultiplier, uint8 delayExemptions) {
        name = boosterCategory[_tokenId].name;
        revealMultiplier = boosterCategory[_tokenId].revealMultiplier;
        unfreezeMultiplier = boosterCategory[_tokenId].unfreezeMultiplier;
        shapeMultiplier = boosterCategory[_tokenId].shapeMultiplier;
        delayExemptions = boosterCategory[_tokenId].delayExemptions;
    }

     function getBoosterTypesss(uint64 _tokenId) external view returns(BoosterType memory) {
        return boosterCategory[_tokenId];
    }

     function getBoosterMultipl(uint64 _tokenId) external view returns(uint16) {
        return boosterCategory[_tokenId].revealMultiplier;
    }

    function addNewBooster(string memory _name, uint16 _rvlMul, uint8 _unfreezeMul, uint16 _shapeMul ) external onlyOwner {
        boosterCount++;
        BoosterType memory bType = BoosterType({
            name: _name,
            revealMultiplier: _rvlMul,
            unfreezeMultiplier: _unfreezeMul,
            shapeMultiplier: _shapeMul,
            delayExemptions: _unfreezeMul
        });
        //TODO:
        //boosterTypes[boosterTypes.length] = bType;
       // boosterTypes[boosterCount] = bType;
    }

    // function getDelayExemptions(uint _tokenId) external view returns(uint8) {

    //     return 2;
    // }

    //TODO: Only ShapeFlip contract should be able to call this
    function updateDelayExemptions(uint64 _boosterId) external {
        boosterCategory[_boosterId].delayExemptions--;
    }
}