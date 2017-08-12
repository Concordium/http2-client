
module Network.HTTP2.Client.Helpers where

import           Data.Time.Clock (UTCTime, getCurrentTime)
import qualified Network.HTTP2 as HTTP2
import qualified Network.HPACK as HPACK
import           Data.ByteString (ByteString)
import           Control.Concurrent (threadDelay)
import           Control.Concurrent.Async (race)

import Network.HTTP2.Client

type PingReply = (UTCTime, UTCTime, Either () (HTTP2.FrameHeader, HTTP2.FramePayload))

ping :: Int -> ByteString -> Http2Client -> IO PingReply
ping timeout msg conn = do
    t0 <- getCurrentTime
    waitPing <- _ping conn msg
    pingReply <- race (threadDelay timeout) waitPing
    t1 <- getCurrentTime
    return $ (t0, t1, pingReply)

type PromiseDataResult = (Either HTTP2.ErrorCode HPACK.HeaderList, [Either HTTP2.ErrorCode ByteString])

sinkAllPromisedData :: Http2Stream -> IncomingFlowControl -> IO PromiseDataResult
sinkAllPromisedData stream streamFlowControl = do
    (_,_,hdrs) <- _waitHeaders stream
    dataFrames <- moredata []
    return (hdrs, reverse dataFrames)
  where
    moredata xs = do
        (fh, x) <- _waitData stream
        if HTTP2.testEndStream (HTTP2.flags fh)
        then
            return xs
        else do
            _updateWindow $ streamFlowControl
            moredata (x:xs)
