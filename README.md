# Texrun

https://hackage.haskell.org/package/texrunner

- diagramsのPGFバックエンドで日本語使いたいが、内部エンジンのtexrunnerがByteStringでやり取りしてる
  - diagramsもだが、pdflatexで使うことが前提になっている模様
- ByteStringの代わりにTextで交信するバージョンを自作してみる
