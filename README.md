# db_tutorial_haskell

cstackの[Let's Build a Simple Database](https://cstack.github.io/db_tutorial/)(sqliteクローンをスクラッチで作るチュートリアル)のHaskell移植。t-wada流のTDDで進める。ロードマップは[PLAN.md](PLAN.md)を参照。

---

## 開発環境

```sh
direnv allow   # または nix develop
```

> [!NOTE]
> devShellに含まれるtricorderはhaskell.nixでビルドされるため、キャッシュ(`cache.iog.io` / `tweag-tricorder.cachix.org`)が使えないとGHCからのソースビルドになる。
> 初回の`nix develop`で`flake.nix`の`nixConfig`を受け入れるか、`nix.conf`に`extra-substituters` / `extra-trusted-public-keys`を追加しておく。

## コマンド

```sh
cabal test                              # テスト実行
cabal run hsdb                          # REPL起動
cabal repl --with-compiler=doctest hsdb # doctest(src/の`>>>`例)
nix fmt                                 # フォーマット(ormolu / hlint / nixfmt / mdformat / ghalint / pinact)
nix flake check                         # ビルド・テスト・整形漏れ・hlint・cabal check(CIでも実行)
nix build                               # 実行バイナリ(.#staticでmusl静的バイナリ)
tricorder ui                            # ファイル変更を監視して継続ビルド・テスト(設定は.tricorder.yaml)
hoogle server --local                   # 依存ライブラリ込みのローカルHoogle
```

## ライブラリの追加

- `hsdb.cabal`の`build-depends`に足す(nixpkgsから取得し、Hackageは参照しない)。
- `.ghci`でデフォルトimportするモジュールは`/sync-ghci`スキルで同期する。

## GHCのバージョンを上げる

`flake.nix`の`ghcVersion`を変更し、`hsdb.cabal`の`base`の下限も合わせる。
`flake.lock`のnixpkgs revは`../acac`と共有しているため、上げるときは両方そろえる。
