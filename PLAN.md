# db_tutorial Haskell移植 計画

cstackの[Let's Build a Simple Database](https://cstack.github.io/db_tutorial/)(C言語でsqliteクローンを作るチュートリアル)をHaskellに移植する。コードは全部自分の手で書く。t-wada流のTDD(Red→Green→Refactor)で進め、Part単位でHaskellのトピックを1つずつ学ぶ。

---

## 1 Partの進め方(毎回この型で回す)

1. **読む**: チュートリアルの該当Partを読み、C版が何をしているか説明できる状態にする(コードはまだ書かない)
2. **TODOリスト化**: この計画のチェックボックスを眺め、必要なら自分の言葉でテストケースを追記・分解する
3. **Red**: 失敗するテストを1つだけ書く(コンパイルエラーもRedのうち)
4. **Green**: 最短で通す。ベタ書きの仮実装でよい
5. **三角測量**: 仮実装のままでは通らない2つ目のテストで一般化を強制する。自明なら最初から明白な実装でよい
6. **Refactor**: テストが緑のまま重複を除去し、`nix fmt`をかける
7. 1サイクルごとにコミット(例: `test: Part1 .exitを認識するRedテスト` → `feat: Part1 .exitで終了`)
8. **ふりかえり**: Part完了時に「学んだこと・詰まったこと」を数行このファイルの末尾にメモする

わからないHaskellの書き方が出てきたら、まず型(`:type`/`:info`をghciで)を調べる→hoogleで探す、の順で自力で調べるのを基本にする。

---

## アーキテクチャ方針(C版との対応)

C版はメモリを直接書き換えながら進むが、Haskellでは「純粋なコア+薄いIOシェル」で作る。

- シリアライズ・ページ操作・B-treeロジック: ByteStringを受け取って返す純粋関数にする。hspecでのunit testが書きやすくなる
- ファイルI/OとREPLループ: IOレイヤに隔離する。REPLはTableの状態を引数で持ち回る再帰ループにすればIORefは不要
- ページはC版と同じ4096バイトのstrict ByteStringで表現し、オフセット計算をそのまま移植する。バイナリのエンコードにはGHC同梱のbinaryパッケージ(Data.Binary.Get/Put)が追加依存なしで使える
- モジュールは最初`Db`1つで始め、育ってきたら分割する(目安: Db.Repl / Db.Statement / Db.Row / Db.Pager / Db.Cursor / Db.BTree)。分割時はhsdb.cabalのexposed-modulesも更新する

### C版の定数(Part 3以降で使用)

| 定数 | 値 |
| --- | --- |
| COLUMN_USERNAME_SIZE | 32 |
| COLUMN_EMAIL_SIZE | 255 |
| ROW_SIZE | 4+32+255 = 291 |
| PAGE_SIZE | 4096 |
| ROWS_PER_PAGE | 14 |
| TABLE_MAX_PAGES | 100 |

C版はnull終端のためPart 4で配列を+1しているが、Haskellでは固定長フィールドを0埋めすればよいので291バイトのままでよい(チュートリアルのE2Eテストは出力文字列しか見ないのでファイル形式の差は問題にならない)。

---

## ロードマップ

### Part 1: REPL

ゴール: `db > `プロンプトを出し、`.exit`で終了、それ以外は`Unrecognized command '...'`と表示する。

学ぶこと(Haskell): 代数的データ型とパターンマッチ、IOモナドと`do`記法、再帰によるREPLループ、`hSetBuffering`。

- [ ] メタコマンド判定の純粋関数(例: `parseMetaCommand :: String -> MetaCommandResult`)が`.exit`を認識する
- [ ] 未知のコマンドで`Unrecognized command`相当の結果を返す
- [ ] IOシェル: `main`でプロンプト表示→1行読む→判定、のループを書く(手動で動作確認)

実装メモ: `hSetBuffering stdout NoBuffering`をしないとプロンプトが出ない。「判定は純粋関数、入出力はmain」の分離をここで体に入れる。

### Part 2: 世界一簡単なSQLコンパイラとVM

ゴール: 入力を「メタコマンド」と「文(statement)」に分け、`insert`/`select`を認識する。

学ぶこと(Haskell): `Either`によるエラー表現(Cのenum返し+出力引数との対比)、`words`での字句分解、ADTでの文の表現。

- [ ] `prepareStatement`が`insert ...`を`StatementInsert`に分類する
- [ ] `select`を`StatementSelect`に分類する
- [ ] 未知の文で`Unrecognized keyword at start of '...'`相当のエラーを返す
- [ ] `executeStatement`(この時点ではスタブ)につなぐ

実装メモ: 結果は`Either PrepareError Statement`で表す。エラーメッセージ文字列はE2E(Part 4)でチュートリアルと突き合わせるので、C版の出力をそのまま写す。

### Part 3: インメモリの単一テーブル(append-only)

ゴール: `insert 1 user1 person1@example.com`で行を追加し、`select`で全行表示する。

学ぶこと(Haskell): strict ByteStringの基本(`take`/`drop`/`replicate`/`append`)、`Word32`とバイナリエンコード(Data.Binary.Get/Put)、レコード構文、純粋な状態(Table)をREPLループで持ち回す設計。

- [ ] Row(id, username, email)を291バイトに直列化できる(`serializeRow`)
- [ ] 直列化した行を元に戻せる(`deserializeRow . serializeRow == id`)
- [ ] insert文の引数をパースしてRowを作れる(引数不足は`Syntax error`)
- [ ] Tableに行を追加すると行数が増え、selectで挿入順に取り出せる
- [ ] 1400行(14行×100ページ)でテーブルフルエラー

実装メモ: この時点のTableは`Vector ByteString`(ページの列)+行数の純粋なレコードでよい。round-trip(直列化→復元)テストはこの先ずっと使う考え方。

### Part 4: テストとバグ修正

ゴール: チュートリアルがrspecで書いているE2EテストをhspecのE2Eとして導入し、境界のバグを直す。

学ぶこと(Haskell): hspecの構造(describe/it/shouldBe)の整理、processパッケージで子プロセスにstdinを流して出力を検証する方法、境界値テストの設計。

- [ ] E2Eヘルパ: ビルド済みバイナリにstdinで複数行流し、stdout全体を比較する(`readProcess`。バイナリのパスは`cabal list-bin hsdb`で取得するか環境変数で渡す)
- [ ] insert→select→.exitの一連の出力が一致する
- [ ] username 32文字ちょうどが挿入できる(境界)
- [ ] 33文字で`String is too long.`エラー
- [ ] 負のidで`ID must be positive.`エラー

実装メモ: C版のバグ(バッファ溢れ)はHaskellでは起きない。それでも同じバリデーションを実装し、「型とテストがどこまで守ってくれるか」の違いを観察する。ここからPartごとにE2Eテストを増やしていく。

### Part 5: ディスク永続化

ゴール: `./hsdb mydb.db`で起動し、`.exit`時にページをファイルへflush、再起動でデータが読める。

学ぶこと(Haskell): ファイルI/O(`Handle`/`hSeek`/`hGetBuf`相当のByteString API)、`IORef`と可変状態を持つ境界の設計、`IntMap`によるページキャッシュ、一時ファイルを使うテスト(directoryパッケージ)。

- [ ] Pager: 指定ページ番号のByteStringを返す(キャッシュ済みならキャッシュから、なければファイルから読む)
- [ ] ファイル長からテーブルの既存行数を計算できる
- [ ] `.exit`で全ページ(最終ページは端数バイトだけ)を書き出す
- [ ] E2E: insert→.exit→再起動→selectで行が残っている

実装メモ: PagerはIOが必須になる境界。`IORef (IntMap ByteString)`+`Handle`を持つレコードにし、ページ内容の計算は純粋関数に寄せる。「どこまでを純粋に保てるか」がこのPartの本題。

### Part 6: カーソル抽象

ゴール: 「テーブル先頭」「テーブル末尾」を指すCursorを導入し、行の読み書きをカーソル経由に置き換える。

学ぶこと(Haskell): テストを命綱にしたリファクタリング、抽象(カーソル)の導入タイミング、レコード更新構文。

- [ ] `tableStart`/`tableEnd`でカーソルを作れる
- [ ] `cursorAdvance`で進み、末尾で`endOfTable`がTrueになる
- [ ] select/insertの実装をカーソル経由にリファクタリング(既存テストが緑のまま)

実装メモ: このPartは新機能ではなくリファクタリング。B-tree導入(Part 7以降)でカーソルの中身だけ差し替えられるようにするのが目的。「振る舞いを変えずに構造を変える」練習。

### Part 7: B-treeの紹介

コードなし(読むだけ)。リーフノード/内部ノードの構造、なぜ配列でなくB-treeなのか(挿入・検索・削除の計算量とディスクアクセス)を理解する。ノートに図を描いて説明できたら完了。

### Part 8: リーフノードのフォーマット

ゴール: ページを「ノード」として扱い、リーフノードのヘッダ(ノード種別・セル数)とセル(key+value)のレイアウトを実装する。テーブルは「ページ0がルート」の1ノードB-treeになる。

学ぶこと(Haskell): バイナリレイアウトの設計(オフセット定数群)、ByteStringのslice操作の抽象化(自作の`readWord32At`/`writeBytesAt`のようなヘルパ)、定数のモジュール化。

- [ ] 空のリーフノードを初期化するとセル数0
- [ ] セルの挿入でセル数が増え、key/valueをオフセットから読み出せる
- [ ] `.constants`メタコマンドで各種定数を表示(E2Eはチュートリアルの期待値と一致させる)
- [ ] `.btree`メタコマンドで木構造を表示
- [ ] リーフノード満杯(13セル)でエラー(分割はPart 10)

実装メモ: レイアウト定数はC版の値をそのまま定数群として写す。ノード操作を`ByteString -> ByteString`の純粋関数にしておくと、以降のB-treeのテストが全部unit testで書ける。

### Part 9: 二分探索と重複キー

ゴール: 挿入位置を二分探索で求め、キー順に格納する。重複キーはエラー。

学ぶこと(Haskell): ループのない二分探索(再帰と不変条件)、三角測量でアルゴリズムを導く体験。

- [ ] `leafNodeFind`が既存キーの位置を返す
- [ ] 存在しないキーでは挿入すべき位置を返す(先頭・中間・末尾の3ケースで三角測量)
- [ ] 重複キーの挿入で`Error: Duplicate key.`
- [ ] E2E: バラバラの順で挿入してもselectはキー順

### Part 10: リーフノードの分割

ゴール: 満杯のリーフノードへの挿入で2つに分割し、新しいルート(内部ノード)を作る。

学ぶこと(Haskell): 「複数ページの更新」を純粋に表す方法(更新されたページ番号→ByteStringのMapを返す等)、複雑なアルゴリズムをテストで刻んで進める練習。

- [ ] 内部ノードのヘッダ・セルのレイアウト定数とアクセサ
- [ ] 分割時の左右セル数(LEFT_SPLIT_COUNT=7, RIGHT_SPLIT_COUNT=7)どおりに振り分けられる
- [ ] 分割後に新ルートが作られ、右子ポインタ・キーが正しい
- [ ] E2E: 14行挿入後の`.btree`出力がチュートリアルと一致

### Part 11: B-treeの再帰探索

ゴール: 内部ノードを辿ってリーフを見つける(`internalNodeFind`)。

学ぶこと(Haskell): 木構造の再帰的な探索(ただしノードはページ上にあるのでPager越し)。

- [ ] 内部ノードから正しい子を選べる(境界キーで三角測量)
- [ ] E2E: 15行挿入して15行目がselectできる

### Part 12: 複数レベルB-treeの走査

ゴール: リーフノードに「次のリーフへのポインタ」を持たせ、selectが全リーフを走査する。

学ぶこと(Haskell): ページ上のリンク構造の走査、Part 6で作ったカーソル抽象が効いてくることの確認。

- [ ] 分割時にnext leafポインタが張り替わる
- [ ] `cursorAdvance`がリーフ末尾で次のリーフへ移る
- [ ] E2E: 15行挿入して15行全部selectできる

### Part 13: 分割後の親ノード更新

ゴール: ルート以外のリーフ分割で親内部ノードへキーを挿入する(チュートリアル最終Part)。

学ぶこと(Haskell): 不変条件(キー順・親子のキー整合)をテストで表現する方法、大きめのシナリオテスト。

- [ ] 親のキー更新(`updateInternalNodeKey`)
- [ ] 内部ノードへの子の挿入(満杯時は`Need to implement splitting internal node`でエラー終了、C版と同じ)
- [ ] E2E: チュートリアル記載の大きめの挿入シナリオで`.btree`出力が一致

---

## 完了の定義(各Part共通)

- `cabal test`が緑
- `nix fmt`(ormolu/nixfmt/mdformat)適用済み
- REPLでの手動動作確認
- 実装に合わせてこのPLAN.mdのチェックボックスと必要ならREADME.mdを更新
- ふりかえりメモを下に追記

---

## ふりかえりメモ

(Part完了ごとに「学んだこと・詰まったこと」を数行追記する)
