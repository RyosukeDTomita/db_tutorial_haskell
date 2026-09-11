{-# OPTIONS_GHC -Wunused-imports #-}

import Test.Hspec

-- 雛形の動作確認用テスト。Part 1の最初のRedテストを書いたら消してよい。
main :: IO ()
main = hspec $ do
  describe "scaffold" $ do
    it "テストスイートが動く" $ do
      (1 + 1 :: Int) `shouldBe` 2
