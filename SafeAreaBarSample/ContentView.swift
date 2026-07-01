import SwiftUI

struct ContentView: View {
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      // A: safeAreaBar 版
      Tab("safeAreaBar", systemImage: "a.circle.fill", value: 0) {
        SafeAreaBarApproach()
      }
      // B: safeAreaInset + 自前 blur 版
      Tab("inset+blur", systemImage: "b.circle.fill", value: 1) {
        SafeAreaInsetApproach()
      }
      Tab("教材", systemImage: "book", value: 2) { DemoList() }
      Tab("ニュース", systemImage: "newspaper", value: 3) { DemoList() }
      Tab("ライブラリ", systemImage: "books.vertical", value: 4) { DemoList() }
    }
  }
}

// MARK: - A. safeAreaBar

/// 「学習履歴」「シチュエーションを作成」を `safeAreaBar` で TabBar の上に配置する版。
/// iOS 26 では bar 背景に Liquid Glass が自動付与され、scroll content は自動で inset される。
private struct SafeAreaBarApproach: View {
  var body: some View {
    DemoList()
      .safeAreaBar(edge: .bottom, spacing: 0) {
        BottomActionButtons()
          .padding(.bottom, 8)
      }
  }
}

// MARK: - B. safeAreaInset + 自前 blur

/// 同じボタン行を `safeAreaInset` で配置し、背景は自前の progressive blur で描く版。
/// blur は `allowsHitTesting(false)` でタッチ透過。ボタン自身は個別にタップを受ける。
private struct SafeAreaInsetApproach: View {
  var body: some View {
    DemoList()
      .safeAreaInset(edge: .bottom, spacing: 0) {
        BottomActionButtons()
          .padding(.bottom, 8)
          .frame(maxWidth: .infinity)
          .background {
            BottomProgressiveBlur()
              .allowsHitTesting(false)
          }
      }
  }
}

// MARK: - 共通パーツ

/// 画像の 2 ボタン行。左に淡い「学習履歴」、右に黒い「シチュエーションを作成」。
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
      .buttonStyle(.glass)
    }
    .padding(.horizontal, 16)
  }
}

/// blur が見えるよう、カード状の行を並べたデモ用リスト。
private struct DemoList: View {
  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        ForEach(0..<40) { i in
          RoundedRectangle(cornerRadius: 16)
            .fill(.quaternary)
            .frame(height: 64)
            .overlay(alignment: .leading) {
              Text("アジェンダの作成 \(i)")
                .font(.headline)
                .padding(.horizontal, 20)
            }
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
    }
  }
}

/// 下端に向かって濃くなるプログレッシブ blur。
/// `.ultraThinMaterial` を上→下の gradient で mask し、上端は透明・下端は blur の帯にする。
private struct BottomProgressiveBlur: View {
  var body: some View {
    Rectangle()
      .fill(.ultraThinMaterial)
      .mask {
        LinearGradient(
          colors: [.clear, .black],
          startPoint: .top,
          endPoint: .bottom
        )
      }
  }
}

#Preview {
  ContentView()
}
