// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBoosters.sol";
import "hardhat/console.sol";

//TODO: Update variables to fit into the model of the game
//TODO: Check for a case where 2 or more players have thesame high score
//TODO: Withdraw funds from the contract
//TODO: Check all Uints
//TODO: Check for when nobody wins a round
//TODO: public and private keywords
//TODO: soulbound


/** 
 * @title ShapeFlip
 * @dev A mini shape flipping game
 */
contract ShapeFlip is ERC721, Ownable {

    //uint256 constant ENTRANCE_COST = 0.005 ether;
    uint256 constant ENTRANCE_COST = 0 ether;
    uint256 constant DEFAULT_PLAYABLE_CARDS = 20;
    //TODO: Implement
    uint32 constant MIN_PLAYER_COUNT = 2;
    enum GameStatus { STARTED, PAUSED, ENDED }
    GameStatus public status;
    mapping(address => uint256) private playersScores;
   //mapping(uint => bool) private passStatus;
   // bool[] passStatus;
    mapping(uint => mapping(uint => bool)) private cards;
    uint private revealedCardCount;
    uint64 gameRound;
    uint private randomCount;
    uint256 private currentTokenId;
    //bytes32[] shapes = ["Square", "Hexagon", "Circle", "Triangle", "Cross"];
    string[6] shapes = ["Square", "Hexagon", "Circle", "Triangle", "Cross", "Star"];
    uint256 private constant COOLDOWN = 0.5 minutes;
    uint256 private startTime;
    uint private gameDuration = 15 minutes;
    IBoosters boosters;

    struct Player {
        uint64 score;
        uint256 timestamp;
        bool allowedToPlay;
    }

    struct Winner {
        uint64 score;
        address winner;
    }

    mapping(address => uint64) private timesWon; 

    //uint represents each round
    mapping(uint64 => mapping(address => Player)) players;
    //mapping(uint64 => Player) roundWinners;
   //  mapping(uint64 => Winner) roundWinners;
    // mapping(uint64 => Winner[]) roundWinners;
       mapping(uint64 => mapping(uint64 => Winner)) private roundWinners;
       uint64 public totalNumberOfWinners;
     //  mapping(uint64 => mapping(address => bool)) private currentWinnersList;

    constructor() ERC721("Shape Flip", "ShapeFlip") {
        gameRound = 0;
        status = GameStatus.PAUSED;
    }

   modifier isValidEntranceCost() {
       require(msg.value == ENTRANCE_COST, "Invalid entrance cost");
       _;
   }

   modifier onlyPassOwner() {
       require(balanceOf(msg.sender) >= 1, "Not a pass owner");
       _;
   }
//allowedToPlay
//    modifier isActivePass(uint _id) {
//        require(passStatus[_id], "Inactive Pass");
//        _;
//    }

    modifier isAllowedToPlay(address _player) {
       require(players[gameRound][_player].allowedToPlay, "Renew or Mint a pass");
       _;
   }
   //function getoundWinners(uint64 _round) external view returns(Player memory) {
   //    return roundWinners[_round];
  // }
   

   function mint() external payable isValidEntranceCost returns (uint256) {
        require(balanceOf(msg.sender) == 0, "Can't mint more than once");
        require(msg.value == ENTRANCE_COST, "!enough money");
       _safeMint(msg.sender, ++currentTokenId);

        //activate pass after mint
      //  passStatus[currentTokenId] = true; 
        players[gameRound][msg.sender].allowedToPlay = true;

        return currentTokenId;
   }

    //TODO: limit length of shapeIds and cardIds by permission of booster
    function playGameWithBooster(uint _tokenId, uint32 _boosterId, uint8[] memory _shapeIds, uint256[] memory _cardIds)
         external onlyPassOwner isAllowedToPlay(msg.sender){

      //  if(boosterType[_boosterId] == 0) {
            // playGame(uint _tokenId, uint8 _shapeId, uint256 _cardId) 
     //   }

       Player storage player = players[gameRound][msg.sender];
       uint64 playerScoreBefore = player.score;

       require(status == GameStatus.STARTED, "Game hasn't started");
       require(block.timestamp > player.timestamp, "Not yet time to play");
       require(ownerOf(_tokenId) == msg.sender, "!NFT owner");
       require(ownerOf(_boosterId) == msg.sender, "!NFT owner");

       //uint16 boosterCategory = boosters.getBoosterCategory(_boosterId);

       (string memory _name, 
       uint16 _revealMultiplier, 
       uint8 _unfreezeMultiplier, 
       uint16 _shapeMultiplier, 
       uint8 _delayExemp) = boosters.getBoosterTypes(_boosterId);
       
       require(_cardIds.length <= _revealMultiplier + 1, "Unauthorized no of cards");
       require(_shapeIds.length <= _shapeMultiplier + 1, "Unauthorized no of shapes");

       for(uint8 i = 0; i < _shapeIds.length; i++ ) {
             require(_shapeIds[i] < shapes.length, "!Allowed shape");
       }

       for(uint i = 0; i < _cardIds.length; i++ ) {
             require(_cardIds[i] > 0 &&_cardIds[i] <= DEFAULT_PLAYABLE_CARDS, "!Playable Card");
             require(cards[gameRound][_cardIds[i]], "Card already revealed");
             cards[gameRound][i] = true;
             ++revealedCardCount;
       }

       //uint32 delayExemptions;
       for(uint8 i = 0; i < _shapeIds.length; i++ ) {
           for(uint j = 0; j < _cardIds.length; j++ ) {
                if(_shapeMatchesWithCard(_shapeIds[i], _cardIds[j], msg.sender)){
                       player.score += 10;
                       //delayExemptions++;
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
           if(_delayExemp > 0){
               boosters.updateDelayExemptions(_boosterId);
           }else{
               //activate cooldown;
               player.timestamp = block.timestamp + COOLDOWN;
           }
       }
 
    // Get one of the winners' score from the list of current winners
        Winner storage currentWinner = roundWinners[gameRound][0];
        bool scoreGreaterThanHighscore = player.score > currentWinner.score;
        bool scoreEqualToHighscore = player.score == currentWinner.score;
    
        //updates the winner of the current round if the
        //score of the current player is higher/equal to the previous score
        if(scoreGreaterThanHighscore){

                    //reset counter/pointer... this is equivalent to deleting an array
                    totalNumberOfWinners = 1;
                    //update new score
                    currentWinner.score = player.score;
                    currentWinner.winner = msg.sender;

        }else if(scoreEqualToHighscore){

            totalNumberOfWinners++;
            roundWinners[gameRound][totalNumberOfWinners].score = player.score;
            roundWinners[gameRound][totalNumberOfWinners].winner = msg.sender;
        }

      

        if(revealedCardCount == DEFAULT_PLAYABLE_CARDS || (block.timestamp - startTime) > gameDuration){
            status =  GameStatus.ENDED;
            
     
      
            //update the amount of times a player has won a round
            for(uint64 i = 0; i < totalNumberOfWinners; i++){
                timesWon[roundWinners[gameRound][i].winner]++;
            }

            //TODO: emit an event that lists out all winners of current round

        }

      
   }
   
   // function playGame(uint _id, uint8[] memory _shapeIds, uint256[] memory _cardIds) external onlyPassOwner isActivePass(_id) {
   function playGame(uint _tokenId, uint8 _shapeId, uint256 _cardId) external onlyPassOwner isAllowedToPlay(msg.sender) {

       Player storage player = players[gameRound][msg.sender];
       require(status == GameStatus.STARTED, "Game hasn't started");
       require(block.timestamp > player.timestamp, "Not yet time to play");
       require(ownerOf(_tokenId) == msg.sender, "!NFT owner");
       require(_shapeId < shapes.length, "!Allowed shape");
       require(_cardId > 0 && _cardId <= DEFAULT_PLAYABLE_CARDS, "!Playable Card");
       require(!cards[gameRound][_cardId], "Card already revealed");
 
        if(_shapeMatchesWithCard(_shapeId, _cardId, msg.sender)){
            player.score += 10;

                // Get one of the winners' score from the list of current winners
                Winner storage currentWinner = roundWinners[gameRound][0];
                bool scoreGreaterThanHighscore = player.score > currentWinner.score;
                bool scoreEqualToHighscore = player.score == currentWinner.score;
            
                //updates the winner of the current round if the
                //score of the current player is higher/equal to the previous score
                if(scoreGreaterThanHighscore){

                            //reset counter/pointer... this is equivalent to deleting an array
                            totalNumberOfWinners = 1;
                            //update new score
                            currentWinner.score = player.score;
                            currentWinner.winner = msg.sender;

                }else if(scoreEqualToHighscore && player.score > 0){

                
                    roundWinners[gameRound][totalNumberOfWinners].score = player.score;
                    roundWinners[gameRound][totalNumberOfWinners].winner = msg.sender;

                    totalNumberOfWinners++;
                }

        } else {
            //activate delay;
            player.timestamp = block.timestamp + COOLDOWN;
        } 

        cards[gameRound][_cardId] = true;
        ++revealedCardCount;

        if(revealedCardCount == DEFAULT_PLAYABLE_CARDS || (block.timestamp - startTime) > gameDuration){
            status =  GameStatus.ENDED;
            
             //update the amount of times a player has won a round
            for(uint64 i = 0; i < totalNumberOfWinners; i++){
                timesWon[roundWinners[gameRound][i].winner]++;
            }

            //TODO: emit an event that lists out all winners of current round
            

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
       bool isMatch = _shapeId == _revealCard(_shapeId, _cardId, _player);
       console.log(isMatch);
      return  isMatch;
   }

   function renewPass(uint _id) external payable isValidEntranceCost onlyPassOwner {
       //require(status == GameStatus.ENDED, "Game hasn't ended");
       require(msg.value == ENTRANCE_COST, "!enough money");
       require(ownerOf(_id) == msg.sender, "!NFT owner");
       //require(!passStatus[_id], "Pass already active");
       require(!players[gameRound][msg.sender].allowedToPlay, "Pass already active");
       players[gameRound][msg.sender].allowedToPlay = true;
   }

 

   function _deActivatePass(uint256 _passId) private {
       require(status == GameStatus.ENDED, "Game hasn't ended");
       //passStatus[_passId] = false; 
       players[gameRound][msg.sender].allowedToPlay = false; 
   }

   function _selectWinner() private {

   }

   function initiateNewRound() external  onlyOwner {
       require(status != GameStatus.STARTED, "Game hasn't started");
       startTime = block.timestamp;
       status = GameStatus.STARTED;
       revealedCardCount = 0;
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

   function setBooster(address _boosters) external onlyOwner {
           boosters =  IBoosters(_boosters);
    }

   function changeGameStatus(GameStatus _status) external onlyOwner {
       status = GameStatus(_status);
   }


   function getTimesWon(address _player) external view returns(uint64) {
       return timesWon[_player];
   }

   

}

//Two ways to check if game has ended...
//If all cards have been revealed
//If the duration of a round has passed

contract AttackContract is IERC721Receiver {

    ShapeFlip shapeFlip;
    uint randomCount;
    uint tokenId;
    
    constructor(address _shapeFlip){
        shapeFlip = ShapeFlip(_shapeFlip);
    }

      function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4){
       return IERC721Receiver.onERC721Received.selector;
    }

    function attack(uint randomCount) external {
        tokenId = shapeFlip.mint();
        uint8 cardId = _revealCard(1, 300, address(this), randomCount);
        shapeFlip.playGame(tokenId, 1, 300);
    }

    function _revealCard(uint8 _shapeId, uint256 _cardId, address _player, uint _randomCount) private returns(uint8) {
      _randomCount++;
      uint8 _revealedCardId = uint8( 
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        _shapeId,
                        _cardId,
                        _player,
                        _randomCount
                    )
                )
            ) % 6
        ); 
      //  console.log("Attack",_revealedCardId);
      return _revealedCardId;
   }

   function attack2(uint randomCount) external {
         uint8 cardId = _revealCard(1, 300, address(this), randomCount);
         shapeFlip.playGame(tokenId, 1, 300);
   }

}
