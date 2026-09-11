{-# OPTIONS_GHC -Wunused-imports #-}

-- | cstack db_tutorial(<https://cstack.github.io/db_tutorial/>)のHaskell移植。
-- PLAN.mdのロードマップに沿ってTDDで実装していく。
-- モジュールが育ってきたらDb.Repl / Db.Statement / Db.Row / Db.Pager /
-- Db.Cursor / Db.BTreeに分割する(分割時はhsdb.cabalのexposed-modulesも更新)。
module Db () where
