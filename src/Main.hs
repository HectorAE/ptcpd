{-|
Module      : Main
Description : PTCP server executable
Copyright   : (c) 2016 Hector A. Escobedo IV
License     : GPL-3
Maintainer  : ninjahector.escobedo@gmail.com
Stability   : experimental
Portability : portable

This high-performance server broadcasts all data received to all hosts
connected to it simultaneously. No metadata, no encryption, just plain text.
|-}

module Main where

import Control.Concurrent
import Control.Concurrent.STM
import Control.Monad

import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Set (Set)
import qualified Data.Set as Set

import Network.Socket
import System.IO (Handle, IOMode(..), hClose)

defaultPortNumber :: PortNumber
defaultPortNumber = 7034

maxMessageSize :: Int
maxMessageSize = 1048576 -- One mebibyte

main :: IO ()
main = do
  channel <- atomically newBroadcastTChan
  connections <- atomically (newTVar Set.empty)
  sock <- socket AF_INET Stream defaultProtocol
  setSocketOption sock ReuseAddr 1
  bindSocket sock (SockAddrInet defaultPortNumber iNADDR_ANY)
  listen sock maxListenQueue
  forever (runConnection sock channel connections)

-- | Check if a certain address is known to be connected.
peerConnected :: TVar (Set SockAddr) -> SockAddr -> STM Bool
peerConnected connections peer = do
  currentPeers <- readTVar connections
  return (peer `Set.member` currentPeers)

-- | If the given address is not listed as connected, add it. Return whether or
-- not this happened.
addPeer :: TVar (Set SockAddr) -> SockAddr -> STM Bool
addPeer connections peer = do
  live <- peerConnected connections peer
  case live of
    True -> return False
    False -> modifyTVar connections (Set.insert peer) >> return True

-- | Analogous to addPeer, but return False if it was not already listed.
removePeer :: TVar (Set SockAddr) -> SockAddr -> STM Bool
removePeer connections peer = do
  live <- peerConnected connections peer
  case live of
    True -> modifyTVar connections (Set.delete peer) >> return True
    False -> return False

runConnection :: Socket -> TChan (SockAddr, ByteString) -> TVar (Set SockAddr) -> IO ()
runConnection sock channel connections = do
  (conn, addr) <- accept sock
  newAddr <- atomically (addPeer connections addr)
  case newAddr of
    True -> do
      hand <- socketToHandle conn ReadWriteMode
      _ <- forkIO (receiveMessages hand addr channel connections)
      clientChannel <- atomically (dupTChan channel)
      _ <- forkIO (sendMessages hand addr clientChannel connections)
      return ()
    False -> do
      close conn
      return ()

receiveMessages :: Handle -> SockAddr -> TChan (SockAddr, ByteString) -> TVar (Set SockAddr) -> IO ()
receiveMessages hand addr channel connections = do
  emptyMessage <- receiveMessage hand addr channel
  case emptyMessage of
    True -> do -- Indicates the connection has been closed on the remote side
      _ <- atomically (removePeer connections addr)
      hClose hand
    False -> receiveMessages hand addr channel connections

receiveMessage :: Handle -> SockAddr -> TChan (SockAddr, ByteString) -> IO Bool
receiveMessage hand addr channel = do
  message <- BS.hGetSome hand maxMessageSize
  let emptyMessage = BS.null message
  unless emptyMessage $ atomically (writeTChan channel (addr, message))
  return emptyMessage

sendMessages :: Handle -> SockAddr -> TChan (SockAddr, ByteString) -> TVar (Set SockAddr) -> IO ()
sendMessages hand addr clientChannel connections = do
  (senderAddr, message) <- atomically (readTChan clientChannel)
  connected <- atomically (peerConnected connections addr)
  case connected of
    True -> do
      unless (senderAddr == addr) (BS.hPut hand message) -- Don't echo back
      sendMessages hand addr clientChannel connections
    False -> return ()
