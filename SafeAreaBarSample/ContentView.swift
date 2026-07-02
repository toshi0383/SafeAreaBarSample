import SwiftUI

// MARK: - 目次（起動画面）

struct ContentView: View {
  var body: some View {
    NavigationStack {
      List {
        Section("採用パターン") {
          NavigationLink("E. 標準tabBar + 独立glassピル") { StandardTabBarWithPillsDemo() }
        }
        Section("比較・ボツパターン") {
          NavigationLink("A. safeAreaBar（全幅でタッチを奪う）") { SafeAreaBarDemo() }
          NavigationLink("B. safeAreaInset + 自前Blur（タッチ透過）") { SafeAreaInsetBlurDemo() }
          NavigationLink("D. tabViewBottomAccessory（カプセル固定）") { TabViewAccessoryDemo() }
        }
      }
      .navigationTitle("下端バー比較")
    }
  }
}

// MARK: - A. safeAreaBar

/// 自動で Liquid Glass 背景 + scroll edge effect。ただしバー全幅でタッチを奪う。
private struct SafeAreaBarDemo: View {
  var body: some View {
    DemoList()
      .safeAreaBar(edge: .bottom, spacing: 0) {
        BottomActionButtons()
      }
      .navigationTitle("A. safeAreaBar")
      .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - B. safeAreaInset + 自前 Blur

/// 自前 progressive blur を背景に敷き、`allowsHitTesting(false)` で Blur 帯はタッチ透過。
private struct SafeAreaInsetBlurDemo: View {
  var body: some View {
    DemoList()
      .safeAreaInset(edge: .bottom, spacing: 0) {
        BottomActionButtons()
          .frame(maxWidth: .infinity)
          .background {
            BottomProgressiveBlur()
              .allowsHitTesting(false)
          }
      }
      .navigationTitle("B. inset + 自前Blur")
      .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - D. tabViewBottomAccessory（標準 tabBar + カプセル）

/// 標準グラス tabBar はそのまま、その上のアクセサリ領域にボタンを乗せる。
/// アクセサリは 1 つのグラスカプセルに包まれる（Apple 管理・自前 Blur 不可）。
private struct TabViewAccessoryDemo: View {
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("ホーム", systemImage: "house.fill", value: 0) { DemoList() }
      Tab("映画・ドラマ", systemImage: "film", value: 1) { DemoList() }
      Tab("教材", systemImage: "book", value: 2) { DemoList() }
    }
    .tabViewBottomAccessory {
      BottomActionButtons()
    }
    .navigationTitle("D. accessory")
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - E. 標準 tabBar + 独立 glass ピル（採用）

/// 標準グラス tabBar の上に、背景なしの safeAreaInset で独立 glass ピルを floating。
/// カプセルも全幅グラス帯も作らないので、隙間・余白は背後にタッチ透過する。
private struct StandardTabBarWithPillsDemo: View {
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("ホーム", systemImage: "house.fill", value: 0) {
        DemoList()
          .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomActionButtons()
          }
      }
      Tab("映画・ドラマ", systemImage: "film", value: 1) { DemoList() }
      Tab("教材", systemImage: "book", value: 2) { DemoList() }
      Tab("ニュース", systemImage: "newspaper", value: 3) { DemoList() }
      Tab("ライブラリ", systemImage: "books.vertical", value: 4) { DemoList() }
    }
    .navigationTitle("E. 標準tabBar + 独立ピル")
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - 共通パーツ

/// 「学習履歴」「シチュエーションを作成」の 2 ボタン行（独立した glass ピル）。
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
    // 画面の丸角に沿わせて水平インセットを画面コーナー半径の半分にする。
    .padding(.horizontal, Screen.displayCornerRadius / 2)
    .padding(.bottom, 16)
  }
}

/// デモ用リスト。
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

/// 画面（ディスプレイ）の角丸半径。公開 API が無いため `UIScreen` の
/// private key を KVC で読む（App Store 提出時はリジェクトのリスクに注意）。
private enum Screen {
  static var displayCornerRadius: CGFloat {
    let screen = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow?.screen }
      .first
    return (screen?.value(forKey: "_displayCornerRadius") as? CGFloat) ?? 0
  }
}

#Preview {
  ContentView()
}
