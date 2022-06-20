// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBoosters.sol";
//import "hardhat/console.sol";

//TODO: Update variables to fit into the model of the game

/** 
 * @title ShapeFlip
 * @dev A mini shape flipping game
 */
contract ShapeFlip is ERC721, Ownable {

    //uint256 constant ENTRANCE_COST = 0.005 ether;
    uint256 constant ENTRANCE_COST = 0 ether;
    uint256 constant DEFAULT_PLAYABLE_CARDS = 5000;
    uint32 constant MIN_PLAYER_COUNT = 10;
    enum GameStatus { STARTED, PAUSED, ENDED }
    GameStatus status = GameStatus.PAUSED;
    mapping(address => uint256) private playersScores;
    mapping(uint => bool) private passStatus;
    mapping(uint => bool) private cards;
    uint revealedCardCount;
    uint64 gameRound;
    //uint private randomCount;
    uint public randomCount;
    uint256 private currentTokenId;
    //bytes32[] shapes = ["Square", "Hexagon", "Circle", "Triangle", "Cross"];
    string[6] shapes = ["Square", "Hexagon", "Circle", "Triangle", "Cross", "Star"];
    //uint freezeTime;

    uint256 private constant COOLDOWN = 10 minutes;
    uint256 private startTime;
    uint private gameDuration = 1 days;
    IBoosters boosters;

    struct Player {
        uint64 score;
        uint256 timestamp;
    }

    struct Winner {
        uint64 score;
        address winner;
    }

    mapping(address => uint64) private timesWon; 

    //uint represents each round
    mapping(uint64 => mapping(address => Player)) players;
    //mapping(uint64 => Player) roundWinners;
     mapping(uint64 => Winner) roundWinners;

    constructor() ERC721("Shape Flip", "ShapeFlip") {
        gameRound = 0;
    }

   modifier isValidEntranceCost() {
       require(msg.value == ENTRANCE_COST, "Invalid entrance cost");
       _;
   }

   modifier onlyPassOwner() {
       require(balanceOf(msg.sender) >= 1, "Not a pass owner");
       _;
   }

   modifier isActivePass(uint _id) {
       require(passStatus[_id], "Inactive Pass");
       _;
   }

   //function getoundWinners(uint64 _round) external view returns(Player memory) {
   //    return roundWinners[_round];
  // }
   
   function getRoundWinner(uint64 _round) external view returns(uint64 _score, address _winner) {
       _score = roundWinners[_round].score;
       _winner = roundWinners[_round].winner;
   } 

   function getTimesWon(address _player) external view returns(uint64) {
       return timesWon[_player];
   }

   function mint() external payable isValidEntranceCost returns (uint256) {
        require(balanceOf(msg.sender) == 0, "Can't mint");
       _safeMint(msg.sender, ++currentTokenId);

        //activate pass after mint
        passStatus[currentTokenId] = true; 

        return currentTokenId;
   }

    //TODO: limit length of shapeIds and cardIds by permission of booster
    function playGame(uint _tokenId, uint32 _boosterId, uint8[] memory _shapeIds, uint256[] memory _cardIds) external onlyPassOwner isActivePass(_tokenId) {

      //  if(boosterType[_boosterId] == 0) {
            // playGame(uint _tokenId, uint8 _shapeId, uint256 _cardId) 
     //   }

       Player storage player = players[gameRound][msg.sender];
       uint64 playerScoreBefore = player.score;

       require(_gameIsOngoing() == GameStatus.STARTED, "Game hasn't started");
       require(block.timestamp > player.timestamp, "Not yet time to play");
       require(ownerOf(_tokenId) == msg.sender, "!NFT owner");
       require(ownerOf(_boosterId) == msg.sender, "!NFT owner");

       for(uint8 i = 0; i < _shapeIds.length; i++ ) {
             require(_shapeIds[i] < shapes.length, "!Allowed shape");
       }

       for(uint i = 0; i < _cardIds.length; i++ ) {
             require(_cardIds[i] > 0 &&_cardIds[i] <= DEFAULT_PLAYABLE_CARDS, "!Playable Card");
             require(cards[_cardIds[i]], "Card already revealed");
             cards[i] = true;
             ++revealedCardCount;
       }

       uint32 delayExemptions;
       for(uint8 i = 0; i < _shapeIds.length; i++ ) {
           for(uint j = 0; j < _cardIds.length; j++ ) {
                if(_shapeMatchesWithCard(_shapeIds[i], _cardIds[j], msg.sender)){
                       player.score += 10;
                       delayExemptions++;
                       break;
                }
           }           
       }

       //if user wins a game, don't use exemption
       //continue the game as usual, no cooldown as well
       //else if user loses a game, check if user has an exemption
       //use it and decrement, no cooldown as well
       //else if user loses a game and has no exemption, 
       // activate cooldown
       if(player.score > playerScoreBefore) {

       }else{
           if(boosters.getDelayExemptions(_boosterId) > 0){
               boosters.updateDelayExemptions(_boosterId);
           }else{
               //activate cooldown;
               player.timestamp = block.timestamp + COOLDOWN;
           }
       }
 

        Winner storage currentWinner = roundWinners[gameRound];
        bool scoreGreaterThanHighscore = player.score > currentWinner.score;
    
        //updates the winner of the current round if the
        //score of the current player is higher than the previous score
        if(scoreGreaterThanHighscore){
                   currentWinner.score =  player.score;
                   currentWinner.winner = msg.sender;
        }

        if(revealedCardCount == DEFAULT_PLAYABLE_CARDS){
            status =  GameStatus.ENDED;
            
             //update the amount of times a player has won a round
            timesWon[currentWinner.winner]++; 

        }
   }
   
   // function playGame(uint _id, uint8[] memory _shapeIds, uint256[] memory _cardIds) external onlyPassOwner isActivePass(_id) {
   function playGame(uint _tokenId, uint8 _shapeId, uint256 _cardId) external onlyPassOwner isActivePass(_tokenId) {

       Player storage player = players[gameRound][msg.sender];
       require(_gameIsOngoing() == GameStatus.STARTED, "Game hasn't started");
       require(block.timestamp > player.timestamp, "Not yet time to play");
       require(ownerOf(_tokenId) == msg.sender, "!NFT owner");
       require(_shapeId < shapes.length, "!Allowed shape");
       require(_cardId > 0 && _cardId <= DEFAULT_PLAYABLE_CARDS, "!Playable Card");
       require(!cards[_cardId], "Card already revealed");
 
        if(_shapeMatchesWithCard(_shapeId, _cardId, msg.sender)){
            player.score += 10;
        } else {
            //activate delay;
            player.timestamp = block.timestamp + COOLDOWN;
        }

        Winner storage currentWinner = roundWinners[gameRound];
        bool scoreGreaterThanHighscore = player.score > currentWinner.score;
    
        //updates the winner of the current round if the
        //score of the current player is higher than the previous score
        if(scoreGreaterThanHighscore){
                   currentWinner.score =  player.score;
                   currentWinner.winner = msg.sender;
        }

        cards[_cardId] = true;
        ++revealedCardCount;

        if(revealedCardCount == DEFAULT_PLAYABLE_CARDS){
            status =  GameStatus.ENDED;
            
             //update the amount of times a player has won a round
            timesWon[currentWinner.winner]++; 

        }
   }

   function _chooseShapes(uint8[] memory _shapeIds) private view {
       for(uint8 i = 0;  i < _shapeIds.length; i++){
            _chooseShape(_shapeIds[i]);
       }
   }

    function _gameIsOngoing() private returns(GameStatus) {
        //require(status == GameStatus.STARTED, "Game hasn't started");
        //check code wella
        if((block.timestamp - startTime) > gameDuration){
            status = GameStatus.ENDED;
        }
        return status;
    }

   function _chooseShape(uint8 _shapeId) private view returns(string memory) {
      return shapes[_shapeId];
   }

   function _revealCards(uint256[] memory _cardIds) private {
       for(uint8 i = 0;  i < _cardIds.length; i++){
        //    _revealCard(_cardIds[i]);
       }
   }
   
   function _revealCard(uint8 _shapeId, uint256 _cardId, address _player) private returns(uint8) {
      randomCount++;
      uint8 _revealedCardId = uint8( 
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        _shapeId,
                        _cardId,
                        _player,
                        randomCount
                    )
                )
            ) % 6
        ); 
      return _revealedCardId;
   }

   function _shapeMatchesWithCard(uint8 _shapeId, uint256 _cardId, address _player) private returns(bool) {
      return  _shapeId == _revealCard(_shapeId, _cardId, _player) ? true : false;
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

   function _deActivatePass(uint256 _passId) private {
       require(status == GameStatus.ENDED, "Game hasn't ended");
        passStatus[_passId] = false; 
   }

   function _selectWinner() private {

   }

   function initiateNewRound() external {
       require(status == GameStatus.ENDED, "Game hasn't ended");
       startTime = block.timestamp;
       status = GameStatus.STARTED;
       gameRound++;
   }

   function getStartTime() external view returns(uint256) {
       return startTime;
   }

   function setEntranceCost() payable external onlyOwner {

   }

   function setCardsAmountPerRound() external onlyOwner {

   }

   function updateMinimumPlayerCount() external onlyOwner {

   }

   function changeGameStatus(GameStatus _status) external onlyOwner {
       status = GameStatus(_status);
   }

//    function initiateNewRound(uint256 _startTime) external onlyOwner {
//        require(status == GameStatus.ENDED, "Game hasn't ended");
//        startTime = _startTime;
//        status = GameStatus.STARTED;
//        gameRound++;
//    }

   

}
