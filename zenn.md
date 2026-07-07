---
title: "徹底検証: safeAreaBar vs. safeAreaInset+自前Blur"
emoji: "🫧"
type: "tech"
topics: ["swiftui", "ios", "ios26", "swift", "liquidglass"]
published: false
---

## この記事でわかること

「学習履歴」「シチュエーションを作成」のようなボタンを、リストの下端やタブバーの上に浮かせたい ── よくある要件です。iOS 26 の Liquid Glass 環境で、実機で試しながら手段を比較していったら、思ったより奥が深かったので整理します。

最初に、この記事でいちばん伝えたい結論を書いておきます。

:::message
下端バーで欲しくなる **「本物の blur の見た目」「隙間のタッチ透過」「標準グラス tabBar」の 3 つは、同時に全部は取れません。** どれを諦めるかを画面ごとに選ぶ、というのが実機検証を経てたどり着いた認識です。
:::

そのうえで、画面タイプ別の推奨は次のとおりです。

- **tabBar のない画面**（オーディオバーのような単独バー）: UIKit の `UIScrollEdgeElementContainerInteraction` + passthrough コンテナが最有力。**本物の scroll edge effect とタッチ透過を両立**できます。SwiftUI だけで完結させたいなら、自前 Blur（疑似）で近似します。
- **標準グラス tabBar のある画面**: tabBar と融合する自前 blur は**どうやっても作れません**。「独立した glass ピルを blur なしで浮かせる」か「`tabViewBottomAccessory`（カプセル）」のどちらかになります。

:::message
検証環境: Xcode 26 / iOS 26.5 Simulator（iPhone 12）。`safeAreaBar` / `.buttonStyle(.glass)` / `.tabViewBottomAccessory` / `UIScrollEdgeElementContainerInteraction` は iOS 26 以降の API です。

検証に使ったサンプルコードは GitHub で公開しています。各パターンを目次から選んで実機比較できるギャラリーアプリになっています。
https://github.com/toshi0383/SafeAreaBarSample
:::

---

## 結論を先に: 何を諦めるかの早見表

| 画面 | 取れる手段 | 代償 |
|---|---|---|
| **標準グラス tabBar を使いたい** | ① 独立 glass ピルを上に floating（`safeAreaInset` に背景を敷かない）<br>② `.tabViewBottomAccessory`（Apple 管理のグラスカプセル） | **自前 Blur で tabBar と融合はできない** |
| **本物の blur とタッチ透過を両立したい** | UIKit の `UIScrollEdgeElementContainerInteraction` + passthrough コンテナ | **標準グラス tabBar とは融合できない**（後述） |
| **SwiftUI だけで単独バーを作りたい** | `safeAreaInset` + 自前 Blur（`.ultraThinMaterial` を gradient mask）＋ `.allowsHitTesting(false)` | blur は本物の scroll edge effect ではない（疑似） |

以下、それぞれの手段の性質と、そこにたどり着くまでにハマった点を書いていきます。

---

## tabBar のない画面: 本物の blur とタッチ透過を両立する

まずは tabBar が絡まない、単独のスクロール画面に下端バーを置くケースです。ここが一番自由度が高く、条件を満たせば「本物の blur ＋ タッチ透過」まで到達できます。

### まず `safeAreaBar` の限界を知る

iOS 26 で追加された `safeAreaBar(edge:spacing:content:)` は `safeAreaInset` の「バー版」です。コンテンツ領域から bar の高さ分を予約しつつ、**bar 背景に Liquid Glass** を付与し、ScrollView の **scroll edge effect（端のぼかし）** も自動で出してくれます。

```swift
ScrollView {
  ForEach(0..<100) { _ in Text("Hello, world!") }
}
.safeAreaBar(edge: .bottom, spacing: 0) {
  BottomActionButtons()
}
```

コード量は最小で、「システム標準のツールバー相当」を出すには最適です。ただし、小さいボタンだけを浮かせたい用途では困る挙動があります。

`safeAreaBar` が敷くグラス背景は **バーの全幅** に広がり、その帯全体がタッチを受け取ります。ボタンが中央に 1 つ乗っているだけでも、**左右の“何もない”ガラス部分までタッチが吸われて**背後のコンテンツに透過しません。タッチを奪う領域に赤く色をつけてみました。

![タッチを奪う領域に赤く色をつけてみました。](https://static.zenn.studio/user-upload/bca0c56c4cf3-20260702.png =350x)

SwiftUI の `safeAreaBar` 側に、この全幅デッドゾーンを回避する手段は見つけられませんでした。「小さいボタンだけ浮かせて、それ以外は透過させたい」用途だと、ここが最初の壁になります。

### SwiftUI だけなら: `safeAreaInset` + 自前 Blur

そこで、配置は `safeAreaInset(edge:.bottom)` にして、背景の Blur は **自前** で描き、Blur に `.allowsHitTesting(false)` を付けて **タッチ透過** させる構成です。

自前の progressive blur は、`.ultraThinMaterial` を上→下の gradient で mask するだけ。上端は透明、下端に向かって濃くなる帯になります。

```swift
/// 下端に向かって濃くなるプログレッシブ Blur。
/// タッチ透過は呼び出し側で `.allowsHitTesting(false)` を付けて制御する。
struct BottomProgressiveBlur: View {
  var body: some View {
    Rectangle()
      .fill(.ultraThinMaterial)
      .mask {
        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
      }
  }
}
```

配置側は次のとおりです。

```swift
ScrollView {
  // ...
}
.safeAreaInset(edge: .bottom, spacing: 0) {
  BottomActionButtons()
    .frame(maxWidth: .infinity)
    .background {
      BottomProgressiveBlur()
        .allowsHitTesting(false)   // ← Blur 帯はタッチ透過。ボタンだけが反応する
    }
}
```

**単独の ScrollView に自前バーを付けるだけ**なら、これがいちばん融通が利きます。Blur の見た目もタッチ挙動も自分で握れます。ただし、この blur は「それっぽい」疑似であって、システムがツールバー下端で出す**本物の scroll edge effect ではない**点は割り切りが要ります。

### 本命: UIKit の scroll edge effect + passthrough コンテナ

iOS 26 の**本物の scroll edge effect** を、**自前ビューに対して**付けることもできます。UIKit の `UIScrollEdgeElementContainerInteraction` を使います。

```swift
// 自前バー（UIView）に付ける。scrollView の下端を通過するコンテンツに
// システムの progressive blur が自動でかかる。
if #available(iOS 26.0, *) {
  let interaction = UIScrollEdgeElementContainerInteraction()
  interaction.scrollView = scrollView
  interaction.edge = .bottom
  barView.addInteraction(interaction)
}
```

そして重要なのが、**この interaction 自体はタッチを奪わない**という点です。コンテナのヒットテストは通常の UIKit のルールに従うので、`hitTest` をオーバーライドした passthrough コンテナにボタンを乗せれば、**「本物の scroll edge effect ＋ 隙間はタッチ透過」が両立**します。SwiftUI の `safeAreaBar` では不可能だった組み合わせです。

```swift
/// 自身へのヒットは無視し、subview（ボタン）へのヒットだけ返すコンテナ。
final class PassthroughView: UIView {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let view = super.hitTest(point, with: event)
    return view === self ? nil : view
  }
}
```

ボタン自体も UIKit で組みます。iOS 26 なら `UIButton.Configuration.glass()` / `.prominentGlass()` で glass ボタンが作れます。SwiftUI の自前バーで使いたい場合も、この一式を `UIViewRepresentable` / `UIViewControllerRepresentable` 経由で載せれば同じことができます。

筆者が開発に携わっている [abceed](https://www.abceed.com/) のオーディオバー（画面下端にフルブリードで pin した自前バー）は、この `UIScrollEdgeElementContainerInteraction` の方式で、`.ultraThinMaterial` ではなくシステム同等の scroll edge blur を出しています。

![](https://static.zenn.studio/user-upload/010bb0e53049-20260702.png =350x)

:::message
abceed が採用しているのは上記の blur の方式だけで、この節で説明した **passthrough コンテナによるタッチ透過の修正はまだリリースしていません**（執筆時点では、バーの余白のタッチは背後に透過しません）。実アプリで確認される方はご注意ください。
:::

### ハマりどころ: `_UIHostingView` が bounds 全域でタッチを吸う

:::message alert
bar の中身を `UIHostingController` でホストすると、`_UIHostingView` が SwiftUI の内容に関係なく **bounds 全域でヒットテストに応答する**ため、ボタンの隙間までタッチが吸われます。検証時、当初これを interaction のせいだと誤認していて、「本物の scroll edge effect ＋ タッチ透過は両立しない」と早合点しかけました。原因は interaction ではなくホスティングビューでした。タッチ透過が必要な bar は、passthrough コンテナ + UIKit のボタンで組むのが確実です。
:::

---

## 標準グラス tabBar のある画面: 融合は諦める

問題は、**標準の `TabView` のグラス tabBar と一緒に使いたい** ときです。「ボタン行と tabBar をまとめて 1 枚の自前 Blur で覆いたい」と思いましたが ── これは SwiftUI でも UIKit でも実現できませんでした。

### 検証: UIKit でも blur は tabBar にクランプされる

「UIKit なら標準 tabBar の直上に自前バー + interaction を置いて、blur を tabBar のグラスまで連続させられるのでは」と考え、`UITabBarController`（標準 Liquid Glass tabBar）の上で試しました。結果は次のとおりです。

- 標準グラス tabBar の直上に自前バー + `UIScrollEdgeElementContainerInteraction` を置いても、**bottom edge effect の描画範囲は tabBar のクロムにクランプされ**、blur の上端を自前バー（ボタン背後）まで拡張できませんでした。
- `setContentScrollView(scrollView, for: .bottom)` の有無で**レンダリング結果は完全に一致**しました（スクリーンショットのハッシュ一致で確認）。

つまり **「標準グラス tabBar と融合する自前 blur」は SwiftUI でも UIKit でも実現不可**、というのが最終検証での結論です。interaction が bar の frame 全域に効くのは、前章のような tabBar のない画面に限られます。

:::message
標準 `TabView` の tabBar のグラスは、システムが管理する別レイヤー（クロム）です。自前 Blur を差し込むことも、背後に回して連続させることもできません。「一枚帯」にしたいなら tabBar を自前実装するしかなく、それは標準グラス tabBar を捨てることになります。標準の見た目・挙動が欲しい場合は本末転倒です。
:::

というわけで、標準 tabBar を保つなら現実解は次の 2 つになります。

### 現実解A: 独立 glass ピルを blur なしで浮かせる

「標準グラス tabBar を保ったまま」「カプセルにせず独立ピルで」「全幅デッドゾーンも作らない」を全部満たす現実解は、実はいちばん素朴でした。**`safeAreaInset` に背景を敷かず、`.buttonStyle(.glass)` のボタンだけを置く** です。

```swift
struct ContentView: View {
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("ホーム", systemImage: "house.fill", value: 0) {
        DemoList()
          // 背景を敷かないので「カプセル」も「全幅グラス帯」も生まれない。
          // ボタン間の隙間・左右マージンは背後コンテンツにタッチ透過する。
          .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomActionButtons()
          }
      }
      Tab("映画・ドラマ", systemImage: "film", value: 1) { DemoList() }
      Tab("教材", systemImage: "book", value: 2) { DemoList() }
      // ...
    }
  }
}

/// 独立した 2 つの浮遊ボタン（カプセルで包まない）。
/// HStack 自体は背景を持たないため、各 glass ボタンだけが当たり判定を持つ。
private struct BottomActionButtons: View {
  var body: some View {
    HStack(spacing: 12) {
      Button {} label: {
        Text("学習履歴").font(.subheadline).bold()
      }
      .buttonStyle(.glass)

      Spacer(minLength: 0)

      Button {} label: {
        Text("シチュエーションを作成").font(.subheadline).bold()
      }
      .buttonStyle(.glassProminent)
    }
    .padding(.horizontal, Screen.edgeInset)
    .padding(.bottom, 16)
  }
}
```

![](https://static.zenn.studio/user-upload/b69cd3287faa-20260702.png =350x)

- tabBar は TabView 標準のグラスのまま（別レイヤー）
- ボタンは独立した glass ピル。`HStack` に背景が無いので、**ピルの当たり判定だけ**がインタラクティブで、隙間・余白・上の領域は背後にタッチ透過
- `safeAreaInset` が高さ分を予約するので、リスト末尾がボタンに隠れない

blur は諦めていますが、標準 tabBar と共存しつつ全幅デッドゾーンも作らない、実務的な着地だと感じました。

### 現実解B: `.tabViewBottomAccessory`（カプセル）

標準 tabBar を保ったままその上にコンテンツを乗せる公式 API が iOS 26 にあります。Apple Music の再生バーのあれです。

```swift
TabView(selection: $selectedTab) {
  Tab("ホーム", systemImage: "house.fill", value: 0) { HomeScreen() }
  Tab("教材", systemImage: "book", value: 1) { LibraryScreen() }
  // ...
}
.tabViewBottomAccessory {
  BottomActionButtons()
}
```

- 標準グラス tabBar はそのまま
- アクセサリにも Liquid Glass が自動付与され、スクロール時は tabBar と inline に統合
- 全幅ベタ塗りではなく **端から内側に浮くカプセル** なので、`safeAreaBar` のような全幅デッドゾーンは無い

ただし **アクセサリは 1 つのグラスカプセルに包まれます**。自前 Blur は使えず、見た目は Apple 管理です。「独立した 2 つの浮遊ピルにしたい」「カプセルにしたくない」場合は合いません。

![](https://static.zenn.studio/user-upload/33018da06542-20260702.png =350x)

---

## 浮遊ピルを画面角と同心に収める

現実解A の話に戻ると、ピルの左右インセットを固定 16pt にすると、画面の丸角に対して間延びしたり詰まって見えることがあります。**画面（ディスプレイ）のコーナー半径**を基準にインセットを決めると、丸角のカーブに馴染んで収まりが良くなります。

### 公開 API でデバイス角丸を取得する（iOS 26+）

デバイスのコーナー半径は、iOS 26 の公開 API `UIView.effectiveRadius(corner:)` で取得できます。ポイントは **`containerConcentric` の `cornerConfiguration` を設定した「画面全体に貼った view」で読む**こと。素の UIView では 0 が返ります。

```swift
/// 公開 API だけでデバイス角丸を計測する reader（ルート画面の背景に敷く）。
struct DisplayCornerRadiusReader: UIViewRepresentable {
  func makeUIView(context: Context) -> ReaderView { ReaderView() }
  func updateUIView(_ uiView: ReaderView, context: Context) {}

  final class ReaderView: UIView {
    override init(frame: CGRect) {
      super.init(frame: frame)
      isUserInteractionEnabled = false
      cornerConfiguration = .corners(radius: .containerConcentric())  // ← これが必須
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
      super.layoutSubviews()
      Screen.displayCornerRadius = effectiveRadius(corner: .bottomLeft)
    }
  }
}
```

ルート画面の背景に敷いて、起動時に一度計測します。

```swift
NavigationStack { /* ... */ }
  .background { DisplayCornerRadiusReader().ignoresSafeArea() }
```

手元の実測（iPhone 12 / iOS 26.5 Simulator）では、この方法の返り値は後述の private API `_displayCornerRadius` と完全に一致（47.33）しました。この方法は X で [@vistar941](https://x.com/vistar941) さんに教えていただきました。ありがとうございます！

### インセットの計算式

簡便には「コーナー半径の半分」（`displayCornerRadius / 2`）を左右インセットに使うだけでも馴染みます。より正確に**画面角と同心**にするなら、コーナー半径から**カプセル自身の半径（＝バー高さ / 2）**を引いた値を floating マージンにします（最小 16pt でクランプ）。abceed のオーディオバーもこの式です。

```swift
enum Screen {
  /// DisplayCornerRadiusReader が起動時に計測して格納する。
  static var displayCornerRadius: CGFloat = 0

  /// バー（カプセル）の高さ。
  static let barHeight: CGFloat = 56

  /// 画面角と同心になる floating マージン。
  static var edgeInset: CGFloat {
    max(displayCornerRadius - barHeight / 2, 16)
  }
}
```

|before|after|
|---|---|
| ![](https://static.zenn.studio/user-upload/629778672b62-20260702.png =250x) | ![](https://static.zenn.studio/user-upload/b69cd3287faa-20260702.png =250x) |

### 参考: iOS 18 以前もサポートする場合（private API）

iOS 18 以前では `effectiveRadius(corner:)` が使えないため、`UIScreen` の private key を KVC で読む方法が知られています。

```swift
let screen = UIApplication.shared.connectedScenes
  .compactMap { ($0 as? UIWindowScene)?.keyWindow?.screen }
  .first
let radius = (screen?.value(forKey: "_displayCornerRadius") as? CGFloat) ?? 0
```

:::message alert
`_displayCornerRadius` は **private API** です。実験や社内配布なら問題ありませんが、App Store 提出ではリジェクトのリスクがあります。複数のアプリで審査通過実績があるので問題ない認識ですが、あくまで自己責任でご利用ください。iOS 26 以降のみをサポートするアプリなら、上記の公開 API を使ってください。
:::

---

## 参考: 他アプリはどうしているか

余談ですが、Slack の iOS アプリは下端に浮くボタンの背景を「透過するぼかし帯」で処理していて、帯の余白では背後のリストがそのままスクロール・タップできます。狭い領域ですが、タブバー左右の余白もタッチ透過になっています。
一方で標準のメールアプリは、このような「ボタンの隙間」をタッチ透過していません。個人的には Slack の挙動のほうが自然に感じるのですが、皆さんはどうでしょうか？

|Slack|標準メール|
|---|---|
|![](https://static.zenn.studio/user-upload/2826f13085a8-20260702.jpg =250x) | ![](https://static.zenn.studio/user-upload/3c6365d10b01-20260702.jpg =250x) |

---

## まとめ: 何を諦めるか

改めて、下端バーの「本物の blur の見た目」「隙間のタッチ透過」「標準グラス tabBar」は、同時に全部は取れません。何を諦めるかの整理が、今回の検証でいちばん価値があった部分でした。

| 欲しいもの | 取れる手段 | 代償 |
|---|---|---|
| **標準グラス tabBar を使う** | 独立 glass ピルを floating（`safeAreaInset` 背景なし）／ `.tabViewBottomAccessory`（カプセル） | 自前 Blur で tabBar と融合はできない |
| **本物の blur ＋ タッチ透過** | UIKit の `UIScrollEdgeElementContainerInteraction` + passthrough コンテナ | 標準グラス tabBar とは融合できない |
| **SwiftUI だけで単独バー** | `safeAreaInset` + 自前 Blur（`.allowsHitTesting(false)`） | 本物の scroll edge effect ではない（疑似） |

手段ごとの一言まとめです。

- `safeAreaBar`: 手軽だが全幅でタッチを奪う。単純なツールバー向け。
- `safeAreaInset` + 自前 Blur: **単独バー**なら Blur もタッチも自由に握れて使いやすい。ただし標準 tabBar とは融合しない。
- UIKit の `UIScrollEdgeElementContainerInteraction` + passthrough: **本物の scroll edge effect ＋ タッチ透過**を両立できる唯一の方法。ただし標準グラス tabBar との融合だけは不可。
- `.tabViewBottomAccessory`: 標準 tabBar の上に乗せる公式手段。ただしカプセル固定・Apple 管理のグラス。
- `safeAreaInset` 背景なし + glass ピル: 標準 tabBar と共存しつつ全幅デッドゾーンも作らない、実務的な着地。

落としどころは画面の要件で変わります。自分が扱ったケースでは、tabBar のある画面は独立ピルを blur なしで floating、tabBar のない単独バーは UIKit の interaction + passthrough、という使い分けに落ち着きました。手段の性質を押さえたうえで、手に馴染む方を選ぶのが良いと思います。


