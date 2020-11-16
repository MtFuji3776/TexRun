# Texrun

https://hackage.haskell.org/package/texrunner

- diagramsのPGFバックエンドで日本語使いたいが、内部エンジンのtexrunnerがByteStringでやり取りしてる
- ByteStringの代わりにTextで交信するバージョンを自作してみる
