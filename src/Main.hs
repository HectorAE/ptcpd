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
-- import Control.Exception
import Control.Concurrent.STM
import Control.Monad

import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Maybe

import Network.Socket hiding (send, sendTo, recv, recvFrom)
import Network.Socket.ByteString
import System.IO (Handle, IOMode(..), hClose, hIsWritable)

defaultPortNumber = 7034
maxMessageSize = 4096 -- In bytes

main :: IO ()
main = do
  channel <- atomically newBroadcastTChan
  sock <- socket AF_INET Stream defaultProtocol
  setSocketOption sock ReuseAddr 1
  bindSocket sock (SockAddrInet defaultPortNumber iNADDR_ANY)
  listen sock maxListenQueue
  forever (runConnection sock channel)

runConnection :: Socket -> TChan (SockAddr, ByteString) -> IO ()
runConnection sock channel = do
  (conn, addr) <- accept sock
  hand <- socketToHandle conn ReadWriteMode
  forkIO (receiveMessages hand addr channel)
  clientChannel <- atomically (dupTChan channel)
  forkIO (sendMessages hand addr clientChannel)
  return ()

receiveMessages :: Handle -> SockAddr -> TChan (SockAddr, ByteString) -> IO ()
receiveMessages hand addr channel = do
  message <- BS.hGetSome hand maxMessageSize
  unless (BS.null message) $ do
    atomically (writeTChan channel (addr, message))
    receiveMessages hand addr channel
  -- After EOF (connection closed)
  hClose hand

-- TODO: Make this exception-safe
sendMessages :: Handle -> SockAddr -> TChan (SockAddr, ByteString) -> IO ()
sendMessages hand addr clientChannel = do
  (senderAddr, message) <- atomically (readTChan clientChannel)
  pipeOpen <- hIsWritable hand
  when pipeOpen $ do
    unless (senderAddr == addr) (BS.hPut hand message) -- Don't echo
    sendMessages hand addr clientChannel
