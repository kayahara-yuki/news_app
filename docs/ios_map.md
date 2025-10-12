# iOS17.0〜使用できるSwiftUI用MapKitのAPIサンプル集

**公開日:** 2024/04/04  
**タグ:** iOS, Swift, map, SwiftUI, MapKit, tech

## 概要

MapKitは主にアプリに地図を表示する際に使用するフレームワークですが、iOS17.0〜SwiftUIに対応した様々なAPIが追加されましたのでサンプル集としてまとめました。

※ MapKitはAppKitとUIKit用とSwiftUI用に分かれていますのでUIKit用のAPIを見たい方は[こちら](リンク先)からどうぞ。

## 環境

この記事は以下のバージョン環境のもと作成されたものです。
- **Xcode:** 15.1
- **iOS:** 17.0

## サンプル集

サンプルはGitHubで公開していますのでクローンしてXcodeでビルドするとすぐに試せるようになっています！

また以下ではサンプルの紹介をしていますが、気になるセクションだけ読んだり、そのままコピペで試せるので是非気になる所から読んだり触ったりしてみてください。

### 1. MapStyle Sample

MapStyleを使用して、平面画像からリアルな3D表現まで簡単に表示できるサンプル

### 2. Annotation Sample

カスタマイズしたアノテーションを任意の位置に表示できるサンプル

### 3. MapCircle Sample

地図上の任意の位置を丸で表示するサンプル

### 4. MapPolygon Sample

ポリゴンで覆われた地図上の任意の位置を表示するサンプル

### 5. MapPolyline Sample

地図上の任意の位置に直線を表示するサンプル  
「ルート付きで表示」を切り替えると、さまざまなルートが表示されます

### 6. Marker Sample

地図上の任意の位置にカスタマイズしたマーカーを表示するサンプル

### 7. UserAnnotation Sample

現在位置を表示するサンプル  
MapUserLocationButtonをタップすると現在地が表示されますが、これはプレビューと実機でのみ機能します。  
※アプリが位置情報へアクセスすることを許可した場合のみ使用できます

### 8. MapControls Sample

MapControlsで機能的なボタンを表示するサンプル

### 9. LookAroundPreview Sample

LookAroundPreviewで任意の場所を表示するサンプル  
プレビューのみの表示と地図からの表示を切り替えることができます。

### 10. MapFeature Sample

mapFeatureSelectionContentを使用して地図上の表記をタップしたときに表示される大きなテキストのサンプル

### 11. MapCamera Sample

現在地を瞬時に表示するMapCameraとuserLocationのサンプル  
現在地を表示するにはプレビューまたは実機でのみ動作します  
シミュレーターにはフォールバック位置が表示されます

### 12. MapReader Sample

地図上でタップした位置の経度と緯度を取得するサンプル

### 13. LocalSearch Sample

TextFieldに検索したい文字を入力し、「虫眼鏡」をタップすると地図上に検索結果マーカーが表示され、マーカーをタップするとセーフエリア（下）に詳細情報が表示されるサンプル

## iOS17-MapKit-Sampler

以上サンプル集の紹介でした。上記のサンプルは以下のリンク先に`iOS17-MapKit-Sampler`として公開していますので、cloneしてXcodeでビルドすればすぐにお試しいただけます。  
（良ければ⭐️クリックしてくれると励みになります）

## 最後に

SwiftUIでMapKitを用いると最小1行でマップを表示することができます。

```swift
import SwiftUI
import MapKit

struct ContentView: View {
    var body: some View {
        Map()
    }
}
```

個人的にはMap系は難しいイメージがありましたが、これ程短いコードで壮大なViewを表示できるMapKitが大好きになりました。また今後も良いサンプル思いつきましたら追加していきたいと思いますので`いいね`と感じましたら♡と☆押していただけると励みになります！

## 参考一覧

- MapKit for SwiftUI
- Meet MapKit for SwiftUI

---

**著者:** okayuji  
iOSエンジニア お仕事のご依頼はTwitterのDMからお願いします。

## Discussion

### Ari/蟻 (2025/01/19)
すごくわかりやすくまとめられていて、助かりました。ありがとうございます。

**okayuji (2025/01/19)**  
嬉しいFBありがとうございます！これからも記事を書く上での励みになります！

---

### まった (2025/03/06)
いやーすごい有益なサンプル集ですね。WWDC24で発表されたiOS18以上の機能ですが、以下のようにすればJS版のように大きいカードをモバイルでも表示できます。

```swift
.mapFeatureSelectionAccessory(.callout(.full))
```

ただこのカードのカスタマイズはできないみたいですね。

**okayuji (2025/03/07)**  
そう言っていただき嬉しいです！まったさんのおっしゃる通りiOS18もさらに機能追加されているのでまたどこかで18向けのサンプル集作ってリリースしたいと思います☺️