module Generators where

import Http.Response.Write exposing (writeHtml
  , writeJson
  , writeElm, writeFile
  , writeNode, writeRedirect)

import Http.Request exposing (emptyReq
  , Request, Method(..)
  , parseQuery, getQueryField
  , getFormField, getFormFiles
  , setForm
  )

import Http.Response exposing (Response)
import Http.Server exposing (randomUrl)

import Knox
import Database.Nedb as Database

import Client.App exposing (successView, successfulSignupView)
import Model exposing (Connection, Model)

import Debug
import Maybe
import Result exposing (Result)
import Effects exposing (Effects)
import Dict
import Task exposing (Task, andThen)
import String


--uploadFile : String -> String -> Knox.Client -> Task (Result String String) String
uploadFile fileName fileNameOnServer client =
  Knox.putFile fileName fileNameOnServer client


--generateSuccessPage : Response -> Request -> Model -> Task b ()
generateSuccessPage res req model =
  let
    client =
      Knox.createClient { key = model.key, secret = model.secret, bucket = model.bucket }

    newPath originalFilename =
      String.join "/"
        [ name
        , email
        , originalFilename
        ]

    name =
      getFormField "name" req.form
        |> Maybe.withDefault "anon"

    email =
      getFormField "email" req.form
        |> Maybe.withDefault "anon"

    view =
      successView name

    handleFiles =
      case getFormFiles req.form of
        [] -> Debug.log "no files" <| Task.succeed "failed"
        x::_ ->
          uploadFile x.path (newPath x.originalFilename) client

  in
    handleFiles `andThen` (\url -> writeNode (view url) res)

insertUserIntoDatabase : Request -> Model -> Task a String
insertUserIntoDatabase req model =
  let
    name =
      getFormField "name" req.form
        |> Maybe.withDefault "anon"

    email =
      getFormField "email" req.form
        |> Maybe.withDefault "anon"
  in
    Database.insert [{ name = name, email = email }] model.database


generateSignupPage : Response -> Request -> Model -> Task x ()
generateSignupPage res req model =
  let
    name : String
    name =
      getFormField "name" req.form
        |> Maybe.withDefault "anon"
  in
    insertUserIntoDatabase req model
      |> (flip Task.andThen) (\_ -> randomUrl False model.baseUrl)
      |> Task.map (successfulSignupView name)
      |> (flip Task.andThen) (\node -> writeNode node res)
