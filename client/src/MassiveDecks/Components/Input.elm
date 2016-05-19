module MassiveDecks.Components.Input exposing (Message, Model, Change(..), init, initWithExtra, subscriptions, view, update)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Json

import MassiveDecks.Util exposing (..)
import MassiveDecks.Components.Icon exposing (..)


{-| Messages for changes to the input.
-}
type alias Message id = (id, Change)


{-| Changes to the input.
-}
type Change
  = Changed String
  | Error (Maybe String)


{-| The state of the input.
-}
type alias Model id msg =
  { identity : id
  , class : String
  , label : List (Html msg)
  , placeholder : String
  , value : String
  , error : Maybe String
  , extra : (String -> List (Html msg))
  , embedMethod : Message id -> msg
  }


{-| Create the initial model.

The identity is unique to the input, used to differentiate between different inputs.
The class is the class of the wrapping div.
The label is any HTML that will be inserted into the lable after the info icon.
The value is the initial value of the input. If the input update is run, this will always contain the value currently
shown in the textbox - however, changing it will not change the value of the textbox.
The placeholder is a value to show if no value is entered.
The error is a message that will appear next to the input if set.
The extraMethod is a method to produce anything to be added to the input (e.g: a submit button). It will be given the
current value.
The embedMethod is how to wrap the input message for the surrounding message type.
-}
init : id -> String -> List (Html msg) -> String -> String -> (Message id -> msg) -> Model id msg
init identity class label value placeholder embedMethod =
  initWithExtra identity class label value placeholder (\_ -> []) embedMethod


{-| Create the initial model with some extra content. See init for most of how this works.

The extraMethod is a method to produce anything to be added to the input (e.g: a submit button). It will be given the
current value.
-}
initWithExtra : id -> String -> List (Html msg) -> String -> String -> (String -> List (Html msg)) -> (Message id -> msg) -> Model id msg
initWithExtra identity class label value placeholder extra embedMethod =
  { identity = identity
  , class = class
  , label = label
  , value = value
  , placeholder = placeholder
  , error = Nothing
  , extra = extra
  , embedMethod = embedMethod
  }


{-| Subscriptions for the input.
-}
subscriptions : Model id msg -> Sub (Message id)
subscriptions model = Sub.none


{-| Render the input.
-}
view : Model id msg -> Html msg
view model =
  div [ class model.class ]
    ([ div [ class "mui-textfield" ]
        ([ input [ type' "text"
                 , defaultValue model.value
                 , placeholder model.placeholder
                 , on "input" (Json.map (\value -> (model.embedMethod (model.identity, Changed value))) targetValue)
                 ] []
         , label [] (List.append [ icon "info-circle", text " " ] model.label)
         ] `andMaybe` (error model.error))
     ] ++ model.extra model.value)


{-| Render an error message for the input.
-}
error : Maybe String -> Maybe (Html msg)
error message = Maybe.map (\error -> span [ class "input-error" ] [ icon "exclamation", text " ", text error ]) message


{-| Handles messages and alters the model as appropriate.
-}
update : Message id -> Model id msg -> (Model id msg, Cmd msg)
update message model =
  let
    (identity, change) = message
    newModel =
      if (identity == model.identity) then
        case change of
          Changed value ->  { model | value = value }
          Error error -> { model | error = error }
      else
        model
  in
    (newModel, Cmd.none)
