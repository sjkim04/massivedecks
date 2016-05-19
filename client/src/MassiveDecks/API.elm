module MassiveDecks.API exposing (..)

import Json.Decode as Decode exposing ((:=))
import Json.Encode as Encode

import MassiveDecks.API.Request exposing (..)
import MassiveDecks.Models.Game as Game
import MassiveDecks.Models.Player as Player exposing (Player)
import MassiveDecks.Models.JSON.Decode exposing (..)
import MassiveDecks.Models.JSON.Encode exposing (..)


{-| Makes a request to create a new game lobby to the server. On success, returns that lobby.
-}
createLobby : Request Never Game.Lobby
createLobby = request "POST" "/lobbies" Nothing [] lobbyDecoder


{-| Errors specific to new player requests.
* `NameInUse` - The request was to create a new player with a name already being uses in that lobby.
* `LobbyNotFound` - The given lobby does not exist.
-}
type NewPlayerError
  = NameInUse
  | LobbyNotFound

{-| Makes a request to add a new player to the given lobby. On success, returns a `Secret` for that player.
-}
newPlayer : String -> String -> Request NewPlayerError Player.Secret
newPlayer gameCode name =
  request
    "POST"
    ("/lobbies/" ++ gameCode ++ "/players")
    (Just (encodeName name))
    [ ((400, "name-in-use"), Decode.succeed NameInUse)
    , ((404, "lobby-not-found"), Decode.succeed LobbyNotFound)
    ]
    playerSecretDecoder


{-| Get the lobby and the hand for the player with the given secret (using it to authenticate).
-}
getLobbyAndHand : String -> Player.Secret -> Request Never Game.LobbyAndHand
getLobbyAndHand = commandRequest "getLobbyAndHand" [] []


{-| Errors specific to add deck requests.
* `CardcastTimeout` - The server timed out trying to retrieve the deck from Cardcast.
* `DeckNotFound` - The given play code does not resolve to a Cardcast deck.
-}
type AddDeckError
  = CardcastTimeout
  | DeckNotFound

{-| Makes a request to add the deck for the given play code to the game configuration, using the given secret to
authenticate.
-}
addDeck : String -> Player.Secret -> String -> Request AddDeckError Game.LobbyAndHand
addDeck gameCode secret deckId =
  commandRequest
    "addDeck"
    [ ("deckId", Encode.string deckId) ]
    [ ((502, "cardcast-timeout"), Decode.succeed CardcastTimeout)
    , ((400, "deck-not-found"), Decode.succeed DeckNotFound)
    ]
    gameCode
    secret


{-| Makes a request to the server to add a new AI player to the game.
-}
newAi : String -> Request Never ()
newAi gameCode =
  request
    "POST"
    ("/lobbies/" ++ gameCode ++ "/players/newAi")
    Nothing
    []
    (Decode.succeed ())


{-| Errors specific to starting a new game.
* `NotEnoughPlayers` - There are not enough players in the lobby to start the game. The required number is given.
* `GameInProgress` - There is already a game in progress.
-}
type NewGameError
  = NotEnoughPlayers Int
  | GameInProgress


{-| Makes a request to the server to start a new game in the given lobby, using the given secret to authenticate.
-}
newGame : String -> Player.Secret -> Request NewGameError Game.LobbyAndHand
newGame gameCode secret =
  commandRequest
    "newGame"
    []
    [ ((400, "game-in-progress"), Decode.succeed GameInProgress)
    , ((400, "not-enough-players"), Decode.object1 NotEnoughPlayers ("required" := Decode.int))
    ]
    gameCode
    secret


{-| Errors specific to choosing a winner for the round.
* `NotCzar` - The player is not the card czar.
-}
type ChooseError
  = NotCzar

{-| Make a request to choose the given (by index) winning response for round for the given lobby, using the given secret
to authenticate.
-}
choose : String -> Player.Secret -> Int -> Request ChooseError Game.LobbyAndHand
choose gameCode secret winner =
  commandRequest
    "choose"
    [ ("winner", Encode.int winner) ]
    [ ((400, "not-czar"), Decode.succeed NotCzar) ]
    gameCode
    secret


{-| Errors specific to playing responses into the round.
* `NotInRound` - The player is not in the round, and therefore can't play (i.e.: They are card czar, joined mid-round
*                or were skipped.)
* `AlreadyPlayed` - The player has already played into the round.
* `AlreadyJudging` - The round is in the judging phase, no more cards can be played.
* `WrongNumberOfCards` - The wrong number of cards were played, with the number got, and the number expected.
-}
type PlayError
  = NotInRound
  | AlreadyPlayed
  | AlreadyJudging
  | WrongNumberOfCards Int Int

{-| Make a request to play the given (by index) cards from the player's hand into the round for the given lobby, using
the given secret to authenticate.
-}
play : String -> Player.Secret -> List Int -> Request PlayError Game.LobbyAndHand
play gameCode secret ids =
  commandRequest
    "play"
    [ ("ids", Encode.list (List.map Encode.int ids)) ]
    [ ((400, "not-in-round"), Decode.succeed NotInRound)
    , ((400, "already-played"), Decode.succeed AlreadyPlayed)
    , ((400, "already-judging"), Decode.succeed AlreadyJudging)
    , ((400, "wrong-number-of-cards-played"), Decode.object2 WrongNumberOfCards ("got" := Decode.int) ("expected" := Decode.int))
    ]
    gameCode
    secret


{-| Errors specific to skipping a player in the lobby.
* `NotEnoughPlayersToSkip` - The number of active players would drop below the minimum if the given players were
*                            skipped.
* `PlayersNotSkippable` - One of the given players was not in a state where they could be skipped (i.e.: not
*                         disconnected or timed out).
-}
type SkipError
  = NotEnoughPlayersToSkip
  | PlayersNotSkippable

{-| Make a request to skip the given players in the given lobby using the given secret to authenticate.
-}
skip : String -> Player.Secret -> List Player.Id -> Request SkipError Game.LobbyAndHand
skip gameCode secret players =
  commandRequest
    "skip"
    [ ("players", Encode.list (List.map Encode.int players)) ]
    [ ((400, "not-enough-players-to-skip"), Decode.succeed NotEnoughPlayersToSkip)
    , ((400, "players-must-be-skippable"), Decode.succeed PlayersNotSkippable)
    ]
    gameCode
    secret


{-| Make a request to stop being skipped.
-}
back : String -> Player.Secret -> Request Never Game.LobbyAndHand
back = commandRequest "back" [] []


{- Private -}


{-| Construct a request for a command.
-}
commandRequest : String -> List ( String, Encode.Value ) -> List (KnownError a) -> String -> Player.Secret -> Request a Game.LobbyAndHand
commandRequest name args errors gameCode secret =
  request "POST" ("/lobbies/" ++ gameCode) (Just (encodeCommand name secret args)) errors lobbyAndHandDecoder
