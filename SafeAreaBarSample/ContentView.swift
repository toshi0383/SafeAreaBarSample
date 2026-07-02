import SwiftUI

struct ContentView: View {
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("ホーム", systemImage: "house.fill", value: 0) {
        DemoList()
          // 標準グラス tabBar の上に、独立した glass ボタンを浮かせる。
          // safeAreaInset に背景を敷かないので「カプセル」にはならず、
          // ボタン間の隙間・左右の余白は背後コンテンツにタッチ透過する。
          .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomActionButtons()
          }
      }
      Tab("映画・ドラマ", systemImage: "film", value: 1) { DemoList() }
      Tab("教材", systemImage: "book", value: 2) { DemoList() }
      Tab("ニュース", systemImage: "newspaper", value: 3) { DemoList() }
      Tab("ライブラリ", systemImage: "books.vertical", value: 4) { DemoList() }
    }
  }
}

/// 独立した 2 つの浮遊ボタン（カプセルで包まない）。
/// HStack 自体は背景を持たないため、Spacer の隙間はタッチ透過。各 glass ボタンだけが反応する。
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
    // 画面の角丸に沿わせて水平インセットを画面コーナー半径の半分にする。
    .padding(.horizontal, Screen.displayCornerRadius / 2)
    .padding(.bottom, 16)
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

#Preview {
  ContentView()
}
