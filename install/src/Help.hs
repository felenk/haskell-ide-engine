-- |Module for Help messages and traget descriptions
module Help where

import           Development.Shake
import           Data.List                                ( intercalate )

import           Env
import           Print
import           Version
import           BuildSystem

stackCommand :: TargetDescription -> String
stackCommand target = "stack install.hs " ++ fst target ++ " [options]"

cabalCommand :: TargetDescription -> String
cabalCommand target = "cabal v2-run install.hs --project-file install/shake.project -- " ++ fst target ++ " [options]"

buildCommand :: TargetDescription -> String
buildCommand | isRunFromCabal = cabalCommand
             | otherwise = stackCommand

printUsage :: Action ()
printUsage = do
  printLine ""
  printLine "Usage:"
  printLineIndented (stackCommand templateTarget)
  printLineIndented "or"
  printLineIndented (cabalCommand templateTarget)

-- | short help message is printed by default
shortHelpMessage :: Action ()
shortHelpMessage = do
  hieVersions <- getHieVersions
  printUsage
  printLine ""
  printLine "Targets:"
  mapM_ (printLineIndented . showHelpItem (spaces hieVersions)) (targets hieVersions)
  printLine ""
 where
  spaces hieVersions = space (targets hieVersions)
  targets hieVersions =
    [ ("help", "Show help message including all targets")
    , emptyTarget
    , buildTarget
    , buildLatestTarget
    , hieTarget $ last hieVersions
    , buildDataTarget
    , cabalGhcsTarget
    ]

-- | A record that specifies for each build system which versions of @hie@ can be built.
data BuildableVersions = BuildableVersions
  { stackVersions :: [VersionNumber]
  , cabalVersions :: [VersionNumber]
  }

getDefaultBuildSystemVersions :: BuildableVersions -> [VersionNumber]
getDefaultBuildSystemVersions BuildableVersions {..}
  | isRunFromStack = stackVersions
  | isRunFromCabal = cabalVersions
  | otherwise      = error $ "unknown build system: " ++ buildSystem

helpMessage :: BuildableVersions -> Action ()
helpMessage versions@BuildableVersions {..} = do
  printUsage
  printLine ""
  printLine "Targets:"
  mapM_ (printLineIndented . showHelpItem spaces) targets
  printLine ""
  printLine "Options:"
  mapM_ (printLineIndented . showHelpItem spaces) options
  printLine ""
 where
  spaces = space targets
  -- All targets the shake file supports
  targets :: [(String, String)]
  targets = intercalate
    [emptyTarget]
    [ generalTargets
    , defaultTargets
    , if isRunFromCabal then [cabalGhcsTarget] else [stackDevTarget]
    , [macosIcuTarget]
    ]
  options = [ ("-j[N], --jobs[=N]", "Allow N jobs/threads at once [default number of CPUs].")
            , ("-s, --silent", "Don't print anything.")
            , ("-q, --quiet", "Print less (pass repeatedly for even less).")
            , ("-V, --verbose", "Print more (pass repeatedly for even more).")
            ]

  -- All targets with their respective help message.
  generalTargets = [helpTarget]

  defaultTargets = [buildTarget, buildLatestTarget, buildDataTarget]
    ++ map hieTarget (getDefaultBuildSystemVersions versions)

-- | Empty target. Purpose is to introduce a newline between the targets
emptyTarget :: (String, String)
emptyTarget = ("", "")

templateTarget :: (String, String)
templateTarget = ("<target>", "")

hieTarget :: String -> TargetDescription
hieTarget version =
  ("hie-" ++ version, "Install hie for GHC version " ++ version)

buildTarget :: TargetDescription
buildTarget = ("hie", "Install hie with the latest available GHC and the data files")

buildLatestTarget :: TargetDescription
buildLatestTarget = ("latest", "Install hie with the latest available GHC")

buildDataTarget :: TargetDescription
buildDataTarget =
  ("data", "Get the required data-files for `hie` (Hoogle DB)")

-- special targets

macosIcuTarget :: TargetDescription
macosIcuTarget = ("icu-macos-fix", "Fixes icu related problems in MacOS")

helpTarget :: TargetDescription
helpTarget = ("help", "Show help message including all targets")

cabalGhcsTarget :: TargetDescription
cabalGhcsTarget =
  ( "ghcs"
  , "Show all GHC versions that can be installed via `cabal-build`."
  )

stackDevTarget :: TargetDescription
stackDevTarget = ("dev", "Install hie with the default stack.yaml")