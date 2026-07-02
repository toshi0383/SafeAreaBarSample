---
title: "iOS 26 で下端にボタンを浮かせる: safeAreaBar / safeAreaInset+自前Blur / tabViewBottomAccessory の使い分け"
emoji: "🫧"
type: "tech"
topics: ["swiftui", "ios", "ios26", "swift", "liquidglass"]
published: false
---

## この記事でわかること

- ScrollView / TabView の下端に「浮くボタン」を置く iOS 26 の 3 つの手段と、それぞれの向き・不向き
- `safeAreaBar` の Liquid Glass 背景が **バー全幅でタッチを奪う** 問題
- `safeAreaInset` + 自前 Blur で **タッチを透過** させる方法
- そして最終的にぶつかった結論: **標準グラス tabBar と「融合する自前 Blur」は同時に成立しない**

「学習履歴」「シチュエーションを作成」のようなボタンを、リストの下端・タブバーの上に浮かせたい ── よくある要件です。iOS 26 の Liquid Glass 環境で、実機で試しながら手段を比較していったら、思ったより奥が深かったので整理します。

:::message
検証環境: Xcode 26 / iOS 26.5 Simulator。`safeAreaBar` / `.buttonStyle(.glass)` / `.tabViewBottomAccessory` は iOS 26 以降の API です。
:::

---

## 手段①: `safeAreaBar`

iOS 26 で追加された `safeAreaBar(edge:spacing:content:)` は `safeAreaInset` の「バー版」です。コンテンツ領域から bar の高さ分を予約しつつ、**bar 背景に Liquid Glass** を付与し、ScrollView の **scroll edge effect（端のぼかし）** も自動で出してくれます。

```swift
ScrollView {
  ForEach(0..<100) { _ in Text("Hello, world!") }
}
.safeAreaBar(edge: .bottom, spacing: 0) {
  BottomActionButtons()
}
```

コード量は最小で、「システム標準のツールバー相当」を出すには最適です。

### 注意点: Liquid Glass 背景が「バー全幅でタッチを奪う」

`safeAreaBar` が敷くグラス背景は **バーの全幅** に広がり、その帯全体がタッチを受け取ります。ボタンが中央に 1 つ乗っているだけでも、**左右の“何もない”ガラス部分までタッチが吸われて**背後のコンテンツに透過しません。

「小さいボタンだけ浮かせて、それ以外は透過させたい」用途だと、この全幅デッドゾーンが邪魔に感じました。

---

## 手段②: `safeAreaInset` + 自前 Blur（タッチ透過できる）

そこで、配置は `safeAreaInset(edge:.bottom)`、背景の Blur は **自前** で描き、Blur に `.allowsHitTesting(false)` を付けて **タッチ透過** させる構成です。

余談ですが、Slack の iOS アプリも下端に浮くボタンの背景をこうした「透過するぼかし帯」で処理していて、帯の余白では背後のリストがそのままスクロール・タップできます。個人的にはこの挙動が自然に感じます。

### 自前 progressive blur

`.ultraThinMaterial` を上→下の gradient で mask するだけ。上端は透明、下端に向かって濃くなる帯になります。

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

### 配置側

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

**単独の ScrollView に自前バーを付けるだけ**なら、これがいちばん融通が利きます。Blur の見た目もタッチ挙動も自分で握れます。

---

## ここで壁: 「標準グラス tabBar」と組み合わせたい

問題は、**標準の `TabView` のグラス tabBar と一緒に使いたい** ときです。

「ボタン行と tabBar をまとめて 1 枚の自前 Blur で覆いたい」と思って `safeAreaInset` に tabBar ごと入れようとしましたが ── うまくいきません。

理由: **標準 `TabView` の tabBar のグラスは、システムが管理する別レイヤー（クロム）** です。その素材に自前 Blur を差し込むことも、背後に自前 Blur を回して連続させることもできません。自前 Blur が置けるのは常に **tabBar より上のコンテンツ層** だけで、tabBar とは必ずレイヤーが分かれます。

> 「一枚帯」にしたくて tabBar を自前実装すれば Blur は繋げられますが、それは**標準グラス tabBar を捨てる**ことになります。標準の見た目・挙動が欲しい場合は本末転倒です。

---

## 手段③: `.tabViewBottomAccessory`（標準 tabBar の“上”に乗せる Apple 公式手段）

標準 tabBar を保ったままその上にコンテンツを乗せるための API が iOS 26 にあります。Apple Music の再生バーのあれです。**UIKit は不要** です。

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
- 全幅ベタ塗りではなく **端から内側に浮くカプセル** なので、`safeAreaBar` のような全幅デッドゾーンは無い（これは floating accessory の設計思想であって偶然ではない）

ただし **アクセサリは 1 つのグラスカプセルに包まれます**。自前 Blur は使えず、見た目は Apple 管理。「独立した 2 つの浮遊ピルにしたい」「カプセルにしたくない」場合は合いません。

---

## 実務的な着地: 標準 tabBar + 独立した glass ピル

「標準グラス tabBar を保ったまま」「カプセルにせず独立ピルで」「全幅デッドゾーンも作らない」を全部満たす現実解が、実はいちばん素朴でした。

**`safeAreaInset` に背景を敷かず、`.buttonStyle(.glass)` のボタンだけを置く** です。

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
    .padding(.horizontal, 16)
  }
}
```

- tabBar は TabView 標準のグラスのまま（別レイヤー）
- ボタンは独立した glass ピル。`HStack` に背景が無いので、**ピルの当たり判定だけ**がインタラクティブで、隙間・余白・上の領域は背後にタッチ透過
- `safeAreaInset` が高さ分を予約するので、リスト末尾がボタンに隠れない

---

## 結論: 何を諦めるかの二者択一

| 欲しいもの | 取れる手段 | 代償 |
|---|---|---|
| **標準グラス tabBar を使う** | ① 独立 glass ピルを上に floating（`safeAreaInset` 背景なし）<br>② `.tabViewBottomAccessory`（カプセル・Apple 管理のグラス） | **自前 Blur で tabBar と融合はできない** |
| **自前 Blur で一枚帯に融合したい** | 自前タブバー + 一枚 progressive blur | **標準グラス tabBar を捨てる** |

- `safeAreaBar`: 手軽だが全幅でタッチを奪う。単純なツールバー向け。
- `safeAreaInset` + 自前 Blur: **単独バー**なら Blur もタッチも自由に握れて使いやすい。ただし標準 tabBar とは融合しない。
- `.tabViewBottomAccessory`: 標準 tabBar の上に乗せる公式手段。ただしカプセル固定・Apple 管理のグラス。

そして今回いちばん重要だった学び:

> **標準グラス tabBar と、それと融合する自前 Blur は同時に成立しない。** tabBar のグラスはシステム管理の別レイヤーで、自前 Blur を差し込めない。UIKit（`UITabBar` + `UIVisualEffectView`）に落としても、システム素材とシームレスに合成する公開手段は無いので解決しない。

要件が「標準グラス tabBar」なら自前 Blur との融合は諦め、上に独立ピルを floating させる ── というのが、少なくとも自分が扱ったケースでの落としどころでした。もちろん要件次第なので、手段の性質を押さえたうえで手に馴染む方を選ぶのが良いと思います。
