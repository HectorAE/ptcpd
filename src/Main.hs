{-|
Module      : Main
Description : PTCP server executable
Copyright   : (c) 2016 Hector A. Escobedo IV
License     : GPL-3
Maintainer  : ninjahector.escobedo@gmail.com
Stability   : experimental
Portability : portable

This high-performance server broadcasts all data received to all hosts
connected to it simultaneously. No metadata, no encryption, just the plain text
chat protocol. I recommend using netcat as a client.
|-}

module Main where

import Control.Concurrent
import Control.Concurrent.MVar
import Control.Exception
import Control.Monad

import qualified Data.ByteString as BS
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Maybe

import Network.Socket hiding (send, sendTo, recv, recvFrom)
import Network.Socket.ByteString
import System.IO (Handle, IOMode(..), hClose, hIsWritable)

type SyncMap = MVar (Map SockAddr (MVar ()))

defaultPortNumber = 7034
maxMessageSize = 4096 -- In bytes

main :: IO ()
main = do
  shared <- newEmptyMVar -- Shared conversation buffer
  synced <- newMVar Map.empty -- Map of synced addresses
  -- Create a TCP socket
  sock <- socket AF_INET Stream defaultProtocol
  -- Make it reusable
  setSocketOption sock ReuseAddr 1
  -- Set the port number to listen on
  bindSocket sock (SockAddrInet defaultPortNumber iNADDR_ANY)
  -- Set maximum number of queued connections
  listen sock maxListenQueue
  -- Process connections until the program is terminated
  forever (runConnection sock shared synced)

runConnection :: Socket -> MVar (SockAddr, BS.ByteString) -> SyncMap -> IO ThreadId
runConnection sock shared synced = do
  (conn, addr) <- accept sock
  hand <- socketToHandle conn ReadWriteMode
  forkIO (talk hand addr shared synced)

talk :: Handle -> SockAddr -> MVar (SockAddr, BS.ByteString) -> SyncMap -> IO ()
talk hand addr shared synced = do
  syncmap <- takeMVar synced
  status <- newMVar ()
  putMVar synced $ Map.insert addr status syncmap
  forkIO (receiveMessages hand addr shared synced)
  forkIO (sendMessages hand addr shared synced)
  return ()

receiveMessages :: Handle -> SockAddr -> MVar (SockAddr, BS.ByteString) -> SyncMap -> IO ()
receiveMessages hand addr shared synced = do
  message <- BS.hGetSome hand maxMessageSize
  unless (BS.null message) $ do
    putMVar shared (addr, message)
    receiveMessages hand addr shared synced
  -- After EOF (connection closed)
  syncmap <- takeMVar synced
  putMVar synced $ Map.delete addr syncmap
  hClose hand

sendMessages :: Handle -> SockAddr -> MVar (SockAddr, BS.ByteString) -> SyncMap -> IO ()
sendMessages hand addr shared synced = do
  (senderAddr, message) <- readMVar shared
  syncmap <- readMVar synced
  pipeOpen <- hIsWritable hand
  let syncVar = Map.lookup addr syncmap in
    when ((isJust syncVar) && pipeOpen) $ do
      takeMVar (fromJust syncVar)
      unless (senderAddr == addr) (BS.hPut hand message) -- Don't echo
      putMVar (fromJust syncVar) ()
      mapM_ readMVar syncmap -- Block until all connections are synced
      tryTakeMVar shared
      sendMessages hand addr shared synced
