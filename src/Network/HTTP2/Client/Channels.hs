{-# LANGUAGE CPP #-}

module Network.HTTP2.Client.Channels (
    FramesChan,
    hasStreamId,
    hasTypeId,
    whenFrame,
    whenFrameElse,
    -- re-exports
    module Control.Concurrent.Chan.Lifted,
) where

import Control.Concurrent.Chan.Lifted (Chan, newChan, readChan, writeChan)
import Control.Exception.Lifted (Exception, throwIO)
import Network.HTTP2.Frame (FrameDecodeError, FrameHeader, FramePayload, FrameType, StreamId, framePayloadToFrameType, streamId)

import Network.HTTP2.Client.Exceptions

#if MIN_VERSION_http2(5,0,0)
#else
instance Exception FrameDecodeError
#endif

type FramesChan e = Chan (FrameHeader, Either e FramePayload)

whenFrame ::
    (Exception e) =>
    (FrameHeader -> FramePayload -> Bool) ->
    (FrameHeader, Either e FramePayload) ->
    ((FrameHeader, FramePayload) -> ClientIO ()) ->
    ClientIO ()
whenFrame test frame handle = do
    whenFrameElse test frame handle (const $ pure ())

whenFrameElse ::
    (Exception e) =>
    (FrameHeader -> FramePayload -> Bool) ->
    (FrameHeader, Either e FramePayload) ->
    ((FrameHeader, FramePayload) -> ClientIO a) ->
    ((FrameHeader, FramePayload) -> ClientIO a) ->
    ClientIO a
whenFrameElse test (fHead, fPayload) handleTrue handleFalse = do
    dat <- either throwIO pure fPayload
    if test fHead dat
        then handleTrue (fHead, dat)
        else handleFalse (fHead, dat)

hasStreamId :: StreamId -> FrameHeader -> FramePayload -> Bool
hasStreamId sid h _ = streamId h == sid

hasTypeId :: [FrameType] -> FrameHeader -> FramePayload -> Bool
hasTypeId tids _ p = framePayloadToFrameType p `elem` tids
