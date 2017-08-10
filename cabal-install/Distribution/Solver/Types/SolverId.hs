{-# LANGUAGE DeriveGeneric #-}
module Distribution.Solver.Types.SolverId
    ( SolverId(..)
    )

where

import Codec.Serialise (Serialise)
import Distribution.Package (PackageId, Package(..), UnitId)
import GHC.Generics (Generic)

-- | The solver can produce references to existing packages or
-- packages we plan to install.  Unlike 'ConfiguredId' we don't
-- yet know the 'UnitId' for planned packages, because it's
-- not the solver's job to compute them.
--
data SolverId = PreExistingId { solverSrcId :: PackageId, solverInstId :: UnitId }
              | PlannedId     { solverSrcId :: PackageId }
  deriving (Eq, Ord, Generic)

instance Serialise SolverId

instance Show SolverId where
    show = show . solverSrcId

instance Package SolverId where
  packageId = solverSrcId
