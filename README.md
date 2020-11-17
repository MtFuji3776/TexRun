# Texrun

https://hackage.haskell.org/package/texrunner

- diagramsのPGFバックエンドで日本語使いたいが、内部エンジンのtexrunnerがByteStringでやり取りしてる
  - diagramsもだが、pdflatexで使うことが前提になっている模様
- ByteStringの代わりにTextで交信するバージョンを自作してみる


## コマンド実行時の問題

- 内部実装をよくよく読み解いてみるとByteStringとUTF-8の変換はちゃんと行われていた
- 問題は自分がuplatexを使おうとしていたことにあるようだ
- コマンドで```latexmk,ptex2pdf```を使おうとすると例外が発生する
- それでいて、```command```引数はただ一つのコマンドしか受け付けない
  - 素朴に```dvipdfmx```に繋げる方法は必然的に無理
  - ```uplatex <name> && dvipdfmx <name>```のように書いてもパーサーがエラーを吐く

## lualatexを使うという解決策

- ltjsdocumentクラスを使ってlualatexとしてコンパイルすると日本語が使えて一発でpdf化できる
- onlineTexもこの方法だとうまく日本語pdfを出力することを確認した
- ただ、このやり方で出力したPDFはデフォで100KBくらいのサイズ
  - まとまったフォントデータが埋め込まれているのだろうか？
- とりあえず一つの解決方法としてlualatexを使えば良い。
- uplatexを使う方法については、複数コマンドを受理するタイプの```runOnlineTex'```を自作する方法を考えるとよいのではないか。
