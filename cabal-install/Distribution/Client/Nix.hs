{-# LANGUAGE CPP #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE ViewPatterns #-}

module Distribution.Client.Nix
       ( findNixExpr
       , inNixShell
       , nixInstantiate
       , nixShell
       , nixShellIfSandboxed
       ) where

#if !MIN_VERSION_base(4,8,0)
import Control.Applicative ((<$>))
#endif

import Control.Exception (catch)
import Control.Monad (filterM, when, unless)
import System.Directory
       ( createDirectoryIfMissing, doesDirectoryExist, doesFileExist
       , makeAbsolute, removeDirectoryRecursive, removeFile )
import System.Environment (getExecutablePath, getArgs, lookupEnv)
import System.FilePath
       ( (</>), (<.>), replaceExtension, takeDirectory, takeFileName )
import System.IO (IOMode(..), hClose, openFile)
import System.IO.Error (isDoesNotExistError)
import System.Process (showCommandForUser)

import Distribution.Compat.Semigroup

import Distribution.Verbosity

import Distribution.Simple.Program
       ( Program(..), ProgramDb
       , addKnownProgram, configureProgram, emptyProgramDb, getDbProgramOutput
       , runDbProgram, simpleProgram )
import Distribution.Simple.Setup (fromFlagOrDefault)
import Distribution.Simple.Utils (debug, existsAndIsMoreRecentThan)

import Distribution.Client.Config (SavedConfig(..))
import Distribution.Client.GlobalFlags (GlobalFlags(..))
import Distribution.Client.Sandbox.Types (UseSandbox(..))


configureOneProgram :: Verbosity -> Program -> IO ProgramDb
configureOneProgram verb prog =
  configureProgram verb prog (addKnownProgram prog emptyProgramDb)


touchFile :: FilePath -> IO ()
touchFile path = do
  catch (removeFile path) (\e -> when (isDoesNotExistError e) (return ()))
  createDirectoryIfMissing True (takeDirectory path)
  openFile path WriteMode >>= hClose


findNixExpr :: GlobalFlags -> SavedConfig -> IO (Maybe FilePath)
findNixExpr globalFlags config = do
  -- criteria for deciding to run nix-shell
  let nixEnabled =
        fromFlagOrDefault False
        (globalNix (savedGlobalFlags config) <> globalNix globalFlags)

  if nixEnabled
    then do
      let exprPaths = [ "shell.nix", "default.nix" ]
      filterM doesFileExist exprPaths >>= \case
        [] -> return Nothing
        (path : _) -> return (Just path)
    else return Nothing


nixInstantiate
  :: Verbosity
  -> FilePath
  -> Bool
  -> GlobalFlags
  -> SavedConfig
  -> IO ()
nixInstantiate verb dist force globalFlags config =
  findNixExpr globalFlags config >>= \case
    Nothing -> return ()
    Just shellNix -> do
      alreadyInShell <- inNixShell
      shellDrv <- drvPath dist shellNix
      instantiated <- doesFileExist shellDrv
      -- an extra timestamp file is necessary because the derivation lives in
      -- the store so its mtime is always 1.
      let timestamp = shellDrv <.> "timestamp"
      upToDate <- existsAndIsMoreRecentThan timestamp shellNix

      let ready = alreadyInShell || (instantiated && upToDate && not force)
      unless ready $ do

        let prog = simpleProgram "nix-instantiate"
        progdb <- configureOneProgram verb prog

        removeGCRoots verb dist
        touchFile timestamp

        _ <- getDbProgramOutput verb prog progdb
             [ "--add-root", shellDrv, "--indirect", shellNix ]
        return ()


nixShell
  :: Verbosity
  -> FilePath
  -> GlobalFlags
  -> SavedConfig
  -> IO ()
     -- ^ The action to perform inside a nix-shell. This is also the action
     -- that will be performed immediately if Nix is disabled.
  -> IO ()
nixShell verb dist globalFlags config go = do

  alreadyInShell <- inNixShell

  if alreadyInShell
    then go
    else do
      findNixExpr globalFlags config >>= \case
        Nothing -> go
        Just shellNix -> do

          let prog = simpleProgram "nix-shell"
          progdb <- configureOneProgram verb prog

          cabal <- getExecutablePath

          -- Run cabal with the same arguments inside nix-shell.
          -- When the child process reaches the top of nixShell, it will
          -- detect that it is running inside the shell and fall back
          -- automatically.
          shellDrv <- drvPath dist shellNix
          args <- getArgs
          runDbProgram verb prog progdb
            [ "--add-root", gcrootPath dist </> "result", "--indirect", shellDrv
            , "--run", showCommandForUser cabal args
            ]


drvPath :: FilePath -> FilePath -> IO FilePath
drvPath dist path =
  -- Nix garbage collector roots must be absolute paths
  makeAbsolute (dist </> "nix" </> replaceExtension (takeFileName path) "drv")


gcrootPath :: FilePath -> FilePath
gcrootPath dist = dist </> "nix" </> "gcroots"


inNixShell :: IO Bool
inNixShell = maybe False (const True) <$> lookupEnv "IN_NIX_SHELL"


removeGCRoots :: Verbosity -> FilePath -> IO ()
removeGCRoots verb dist = do
  let tgt = gcrootPath dist
  exists <- doesDirectoryExist tgt
  when exists $ do
    debug verb ("removing Nix gcroots from " ++ tgt)
    removeDirectoryRecursive tgt


nixShellIfSandboxed
  :: Verbosity
  -> FilePath
  -> GlobalFlags
  -> SavedConfig
  -> UseSandbox
  -> IO ()
     -- ^ The action to perform inside a nix-shell. This is also the action
     -- that will be performed immediately if Nix is disabled.
  -> IO ()
nixShellIfSandboxed verb dist globalFlags config useSandbox go =
  case useSandbox of
    NoSandbox -> go
    UseSandbox _ -> nixShell verb dist globalFlags config go
