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
import System.IO (Handle, IOMode(..))

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
  return ()

runConnection :: Socket -> MVar BS.ByteString -> MVar (Map SockAddr Bool) -> IO ThreadId
runConnection sock shared synced = do
  (conn, addr) <- accept sock
  hand <- socketToHandle conn ReadWriteMode
  -- So we can handle multiple connections at once
  tid <- forkIO (talk hand addr shared synced)
  return tid

talk :: Handle -> SockAddr -> MVar BS.ByteString -> MVar (Map SockAddr Bool) -> IO ()
talk hand addr shared synced = do
  updateSynced True
  forever sync
  where
    sync = do
      incoming
      outgoing
    incoming = do
      lastMessage <- tryReadMVar shared
      unless (isNothing lastMessage) $ do
        updateSynced False
        handle ignoreErr (BS.hPut hand (fromJust lastMessage))
        updateSynced True
        waitForAll
        tryTakeMVar shared
        return ()
    outgoing = do
      input <- BS.hGetNonBlocking hand maxMessageSize
      unless (BS.null input) $ do
        waitForAll
        syncmap <- takeMVar synced
        tryTakeMVar shared
        putMVar shared input
        putMVar synced (Map.map (const False) syncmap) -- Alert all
        updateSynced True
        waitForAll
        tryTakeMVar shared
        return ()
    updateSynced b = do
      syncmap <- takeMVar synced
      putMVar synced (Map.insert addr b syncmap)
    waitForAll = do -- Wait until all addresses are synced
      syncmap <- readMVar synced
      unless (and (Map.elems syncmap)) waitForAll
    share a = unless (BS.null a) (putMVar shared a)

-- Very useful when we want to leave dangling sockets and threads, in case
-- someone reconnects right away. May result in major memory leakage.
ignoreErr :: IOError -> IO ()
ignoreErr _ = return ()
