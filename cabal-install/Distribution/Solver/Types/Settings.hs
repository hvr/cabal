{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Distribution.Solver.Types.Settings
    ( ReorderGoals(..)
    , IndependentGoals(..)
    , AvoidReinstalls(..)
    , ShadowPkgs(..)
    , StrongFlags(..)
    , AllowBootLibInstalls(..)
    , EnableBackjumping(..)
    , CountConflicts(..)
    , SolveExecutables(..)
    ) where

import Distribution.Simple.Setup ( BooleanFlag(..) )
import GHC.Generics (Generic)
import Codec.Serialise (Serialise)

newtype ReorderGoals = ReorderGoals Bool
  deriving (BooleanFlag, Eq, Generic, Show)

newtype CountConflicts = CountConflicts Bool
  deriving (BooleanFlag, Eq, Generic, Show)

newtype IndependentGoals = IndependentGoals Bool
  deriving (BooleanFlag, Eq, Generic, Show)

newtype AvoidReinstalls = AvoidReinstalls Bool
  deriving (BooleanFlag, Eq, Generic, Show)

newtype ShadowPkgs = ShadowPkgs Bool
  deriving (BooleanFlag, Eq, Generic, Show)

newtype StrongFlags = StrongFlags Bool
  deriving (BooleanFlag, Eq, Generic, Show)

newtype AllowBootLibInstalls = AllowBootLibInstalls Bool
  deriving (BooleanFlag, Eq, Generic, Show)

newtype EnableBackjumping = EnableBackjumping Bool
  deriving (BooleanFlag, Eq, Generic, Show)

newtype SolveExecutables = SolveExecutables Bool
  deriving (BooleanFlag, Eq, Generic, Show)

instance Serialise ReorderGoals
instance Serialise CountConflicts
instance Serialise IndependentGoals
instance Serialise AvoidReinstalls
instance Serialise ShadowPkgs
instance Serialise StrongFlags
instance Serialise AllowBootLibInstalls
instance Serialise SolveExecutables
