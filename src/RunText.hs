{-# LANGUAGE GeneralizedNewtypeDeriving,OverloadedStrings #-}

module RunText where

import Control.Applicative
import Control.Monad.Reader
import System.Texrunner.Online
import System.Texrunner.Parse
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy.IO as LTIO
import qualified Data.Text.Lazy as LT
import Data.ByteString.Char8 (ByteString)
import qualified Data.ByteString.Char8 as C8
import qualified Data.ByteString.Lazy.Char8 as LC8
import Data.List (find)
import Data.Maybe
import Data.Monoid

import System.Directory
import System.FilePath
import System.IO
import qualified System.IO.Streams as Streams
import System.IO.Streams.Attoparsec
import System.IO.Temp
import System.Process as P (runInteractiveProcess)

import Control.Lens


-- OnlineTexのTextバージョンのつもり
    -- 正確にはTexStreams_の部分が変更点。本家が型定数で定義してたので再定義せざるを得ない
newtype OnlineTex_ a = OnlineTex_ {runOnlineTexT_ :: ReaderT TexStreams_ IO a}
    deriving (Functor,Applicative, Monad, MonadIO, MonadReader TexStreams_) --Genericプログラミング

runOnlineTex'_ :: String 
            -> [String]
            -> ByteString
            -> OnlineTex_ a
            -> IO (a,TexLog,Maybe LT.Text)
runOnlineTex'_ command args preamble process =
    withSystemTempDirectory "onlinetex." $ \path -> do
        (outS, inS, h) <- mkTexHandles path Nothing command args preamble
        a              <- flip runReaderT (outS,inS) . runOnlineTexT_ $ process

        Streams.write Nothing outS
        _ <- Streams.waitForProcess h

        pdfPath <- find ((== ".pdf") . takeExtension) <$> getDirectoryContents path
        pdfFile <- mapM (LTIO.readFile . (path </>)) pdfPath

        logPath <- find ((==".log") . takeExtension) <$> getDirectoryContents path
        logFile <- mapM (C8.readFile . (path </>)) logPath

        return (a,parseLog $ fromMaybe "" logFile , pdfFile)



-- これがうまくいくかどうか
type TexStreams_ = (Streams.OutputStream Text, Streams.InputStream Text)

getOutStream_ :: OnlineTex (Streams.OutputStream Text)
getOutStream_ = reader fst

getInStream_ :: OnlineTex (Streams.OutputStream Text)
getInStream_ = reader snd


mkTexHandles :: FilePath
            -> Maybe [(String,String)]
            -> String
            -> [String]
            -> ByteString
            -> IO (Streams.OutputStream Text,
                   Streams.InputStream Text,
                   Streams.ProcessHandle)
mkTexHandles dir env command args preamble = do
    (outStream,inStream, _,h) <- runInteractiveProcess'_ command args (Just dir) env
    Streams.write (Just preamble) outStream
    return (outStream,inStream,h)

-- これはわざわざ再実装せずとも、本家のrunInteractiveProcess'の戻り値にdecodeUtf8を適用すれば良さそう
    -- io-streamsを見る限り、入出力はどうしてもByteStringにせざるを得ないようだが、UTF-8とのエンコーダ/デコーダが提供されているようだ
    -- 入出力の出入り口のところでエンコーダ/デコーダを噛ませて、あとはパーサーをUTF8からByteStringに変換したものを用意すれば、うまく動くんじゃないだろうか？
runInteractiveProcess'_ :: FilePath -> [String] -> Maybe FilePath -> Maybe [(String,String)]
                        -> IO (Streams.OutputStream Text
                              ,Streams.InputStream Text
                              ,Streams.InputStream Text
                              ,Streams.ProcessHandle)
runInteractiveProcess'_ cmd args wd env = do
    (hin,hout,herr,ph) <- P.runInteractiveProcess cmd args wd env
    let d = Streams.decodeUtf8
        e = Streams.encodeUtf8
    sIn <-  Streams.handleToOutputStream hin  -- この戻り値はByteStringで固定(io-stream)
            >>= Streams.atEndOfInput (hClose hin)
            >>= Streams.lockingOutputStream
            >>= e
    sOut <- Streams.handleToInputStream hout  -- 戻り値はByteStringで固定
            >>= Streams.atEndOfInput (hClose hout)
            >>= Streams.lockingInputStream
            >>= d
    sErr <- Streams.handleToInputStream herr  -- 戻り値はByteStringで固定
            >>= Streams.atEndOfInput (hClose herr)
            >>= Streams.lockingInputStream
            >>= d
    return (sIn,sOut,sErr,ph)

