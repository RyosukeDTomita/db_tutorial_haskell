# db_tutorial_haskell

cstackの[Let's Build a Simple Database](https://cstack.github.io/db_tutorial/)(sqliteクローンをスクラッチで作るチュートリアル)のHaskell移植。t-wada流のTDDで進める。ロードマップは[PLAN.md](PLAN.md)を参照。

---

## 開発環境

```sh
direnv allow   # または nix develop
```

## コマンド

```sh
cabal test          # テスト実行
cabal run hsdb      # REPL起動
nix fmt             # フォーマット(ormolu / nixfmt / mdformat)
```
