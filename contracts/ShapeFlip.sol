// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
/** 
 * @title ShapeFlip
 * @dev A mini shape flipping game
 */
contract ShapeFlip is ERC721 {

    address public owner;
    uint constant ENTRANCE_COST = 0.005 ether;
    enum GameStatus { STARTED, PAUSED, ENDED }
    GameStatus status;
    mapping(address => uint256) private playersScores;
    mapping(uint => bool) private passStatus;
    mapping(uint => bool) private cards;
    uint gameRound;
    //bytes32[] shapes = ["Square", "Hexagon", "Circle", "Triangle", "Cross"];
    string[5] shapes = ["Square", "Hexagon", "Circle", "Triangle", "Cross"];
    //uint freezeTime;

    constructor() ERC721("Shape Flip", "ShapeFlip") {
        owner = msg.sender;
    }

   modifier isValidEntranceCost() {
       require(msg.value == ENTRANCE_COST, "Invalid entrance cost");
       _;
   }

   modifier onlyPassOwner() {
       require(balanceOf(msg.sender) >= 1, "Not a pass owner");
       _;
   }

   modifier onlyOwner() {
       require(owner == msg.sender, "!owner");
       _;
   }

   modifier isActivePass(uint _id) {
       require(passStatus[_id], "Inactive Pass");
       _;
   }
   
   function mint() external payable isValidEntranceCost {
        require(balanceOf(msg.sender) == 0, "Can't mint");
       _safeMint(msg.sender, 1);
   }
   
   function playGame(uint _id, uint8[] memory _shapeIds, uint256[] memory _cardIds) external onlyPassOwner isActivePass(_id) {
       require(_timerIsDisabled(_id), "Not yet time to play");
       _chooseShapes(_shapeIds);
       _revealCards(_cardIds);
   }

   function _chooseShapes(uint8[] memory _shapeIds) private view {
       for(uint8 i = 0;  i < _shapeIds.length; i++){
            _chooseShape(_shapeIds[i]);
       }
   }

   function _chooseShape(uint8 _shapeId) private view returns(string memory) {
      return shapes[_shapeId];
   }

   function _revealCards(uint256[] memory _cardIds) private {
       for(uint8 i = 0;  i < _cardIds.length; i++){
            _revealCard(_cardIds[i]);
       }
   }
   
   function _revealCard(uint256 _cardId) private {

   }

   function _timerIsDisabled(uint256 _id) private returns(bool){

   }

   function renewPass(uint _id) external payable isValidEntranceCost onlyPassOwner {
       require(status == GameStatus.ENDED, "Game hasn't ended");
       require(!passStatus[_id], "Pass already active");
       passStatus[_id] = true; 
   }

   function freezeTime() external {

   }

   function _revealMultiplier() private {

   }

   function setEntranceCost() external onlyOwner {

   }

   function _deActivatePass(uint256 _passId) private {
       require(status == GameStatus.ENDED, "Game hasn't ended");
        passStatus[_passId] = false; 
   }

   function _selectWinner() private {

   }

}