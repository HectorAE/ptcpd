{-|
Module      : Main
Description : PTCP server executable
Copyright   : (c) Hector A. Escobedo IV 2016
|-}

module Main where

import Control.Concurrent
import Control.Concurrent.MVar
import Control.Monad
import qualified Data.ByteString as BS
import Data.Map (Map)
import Data.Maybe
import qualified Data.Map as Map
import Network.Socket hiding (send, sendTo, recv, recvFrom)
import Network.Socket.ByteString
import System.IO (IOMode(..))

defaultPortNumber = 7034
maxMessageSize = 4096 -- In bytes
debugMode = True

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
  conn <- accept sock
  forkIO (talk conn shared synced) -- So we can handle multiple connections at once

talk :: (Socket, SockAddr) -> MVar BS.ByteString -> MVar (Map SockAddr Bool) -> IO ()
talk (sock, addr) shared synced = do
  updateSynced False
  hand <- socketToHandle sock ReadWriteMode
  forever (sync hand)
  where
    sync hand = do
      updateSynced False
      syncmap <- takeMVar synced -- Take control
      input <- BS.hGetNonBlocking hand maxMessageSize
      lastMessage <- tryReadMVar shared
      unless (isNothing lastMessage) $ void $ do
        BS.hPut hand (fromJust lastMessage)
      share input
      putMVar synced syncmap
      updateSynced True
      waitForAll
      when debugMode (putStrLn "Done waiting")
      tryTakeMVar shared -- Remove the last message if possible
    updateSynced b = do
      syncmap <- takeMVar synced
      when debugMode
        (putStrLn ((show addr) ++ " updating to " ++ (show b) ++ " on syncmap"))
      putMVar synced (Map.insert addr b syncmap)
    waitForAll = do -- Wait until all addresses are synced
      syncmap <- readMVar synced
      unless (and (Map.elems syncmap)) waitForAll
    share a = unless (BS.null a) (putMVar shared a)
