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
          NavigationLink("F. UIScrollEdgeElementContainerInteraction（UIKit・本物のedge effect）") { ScrollEdgeInteractionDemo() }
        }
      }
      .navigationTitle("下端バー比較")
    }
  }
}

// MARK: - A. safeAreaBar

/// 自動で Liquid Glass 背景 + scroll edge effect。ただしバー全幅でタッチを奪う。
/// その「タッチを奪う範囲」を赤の半透明で可視化する（この赤い帯の中では背後の
/// リストをスクロール/タップできない）。
private struct SafeAreaBarDemo: View {
  var body: some View {
    DemoList()
      .safeAreaBar(edge: .bottom, spacing: 0) {
        BottomActionButtons()
          .frame(maxWidth: .infinity)
          .background(Color.red.opacity(0.3))
      }
      .navigationTitle("A. safeAreaBar")
      .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - B. safeAreaInset + 自前 Blur（RichAudioBar 風の配置）

/// abceed-ios の RichAudioBar と同じ流儀:
/// - グラスカプセルのオーディオバー（RichAudioBar 相当）+ 2 ボタンを safeAreaInset に置く
/// - バーは物理最下端から `edgeInset` だけ浮かせて floating（画面角と同心）
/// - 背後の自前 blur は `ignoresSafeArea` で物理最下端まで敷く（`allowsHitTesting(false)` で透過）
private struct SafeAreaInsetBlurDemo: View {
  var body: some View {
    DemoList()
      .safeAreaInset(edge: .bottom, spacing: 0) {
        VStack(spacing: 0) {
          // RichAudioBar の上に 2 ボタンを同じように重ねる。
          BottomActionButtons()
          RichAudioBar()
        }
        .frame(maxWidth: .infinity)
        // 物理最下端から edgeInset 分だけ浮かせる（abceed RichAudioBar と同じ）。
        .padding(.bottom, Screen.edgeInset)
        .background {
          BottomProgressiveBlur()
            .allowsHitTesting(false)
        }
        // blur ごと SafeArea を無視して物理最下端まで伸ばす。
        .ignoresSafeArea(.container, edges: .bottom)
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

// MARK: - F. UIScrollEdgeElementContainerInteraction（UIKit・本物の scroll edge effect）

/// abceed の NewsContentViewController と同じ構成:
/// - UIScrollView をフルスクリーンに敷く
/// - bar を全幅で物理最下端 (view.bottomAnchor) に pin
/// - `UIScrollEdgeElementContainerInteraction` を bar に付け、システム本物の
///   progressive blur を bar 背後に出す
/// 注意: blur が出る範囲（= bar の frame）はタッチを奪う。全幅 blur にすると
/// safeAreaBar と同じ全幅デッドゾーンになる（記事の「発展」節の実証用）。
private struct ScrollEdgeInteractionDemo: View {
  var body: some View {
    ScrollEdgeInteractionRepresentable()
      .ignoresSafeArea()
      .navigationTitle("F. UIKit edge effect")
      .navigationBarTitleDisplayMode(.inline)
  }
}

private struct ScrollEdgeInteractionRepresentable: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> ScrollEdgeInteractionViewController {
    ScrollEdgeInteractionViewController()
  }

  func updateUIViewController(_ uiViewController: ScrollEdgeInteractionViewController, context: Context) {}
}

private final class ScrollEdgeInteractionViewController: UIViewController {
  private let scrollView = UIScrollView()
  private var barView: UIView!

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    setupScrollContent()
    setupBar()

    // 本物の scroll edge effect。bar の下を通過するスクロールコンテンツに
    // システムの progressive blur がかかる。
    if #available(iOS 26.0, *) {
      let interaction = UIScrollEdgeElementContainerInteraction()
      interaction.scrollView = scrollView
      interaction.edge = .bottom
      barView.addInteraction(interaction)
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    // bar の高さ分だけ scroll content の下端を予約する（safeAreaInset 相当）。
    let barHeight = barView.bounds.height - view.safeAreaInsets.bottom
    if scrollView.contentInset.bottom != barHeight {
      scrollView.contentInset.bottom = barHeight
    }
  }

  private func setupScrollContent() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)

    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(stack)

    for i in 0..<40 {
      let card = UIView()
      card.backgroundColor = .quaternarySystemFill
      card.layer.cornerRadius = 16
      card.translatesAutoresizingMaskIntoConstraints = false
      let label = UILabel()
      label.text = "アジェンダの作成 \(i)"
      label.font = .preferredFont(forTextStyle: .headline)
      label.translatesAutoresizingMaskIntoConstraints = false
      card.addSubview(label)
      NSLayoutConstraint.activate([
        card.heightAnchor.constraint(equalToConstant: 64),
        label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
        label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
      ])
      stack.addArrangedSubview(card)
    }

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
      stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
      stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
      stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
    ])
  }

  private func setupBar() {
    // bar の中身は SwiftUI（共通の 2 ボタン行）。物理最下端まで bar を伸ばすため、
    // 下パディングを edgeInset にしてボタンをホームインジケータの上に浮かせる。
    let hosting = UIHostingController(
      rootView: BottomActionButtons().padding(.bottom, Screen.edgeInset)
    )
    hosting.view.backgroundColor = .clear
    hosting.safeAreaRegions = []
    addChild(hosting)
    view.addSubview(hosting.view)
    hosting.didMove(toParent: self)

    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      // abceed NewsContentViewController と同じく物理最下端に pin（フルブリード）。
      hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    barView = hosting.view
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
    // 画面角と同心になる edgeInset で左右を floating させる。
    .padding(.horizontal, Screen.edgeInset)
    .padding(.bottom, 16)
  }
}

/// abceed-ios の RichAudioBar 風のオーディオバー。
/// seek バー + 3秒戻し + 再生/停止 + 3秒送り + 速度 を、グラスカプセル背景で包む。
private struct RichAudioBar: View {
  @State private var progress: Double = 0.35
  @State private var isPlaying = false

  var body: some View {
    HStack(spacing: 16) {
      seekTrack

      Button {} label: {
        Image(systemName: "gobackward.5").font(.system(size: 20))
      }
      Button { isPlaying.toggle() } label: {
        Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.system(size: 24))
      }
      Button {} label: {
        Image(systemName: "goforward.5").font(.system(size: 20))
      }

      Text("1.0x").font(.subheadline).bold()
    }
    .foregroundStyle(.primary)
    .buttonStyle(.plain)
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .glassEffect(in: .capsule)
    // 画面角と同心になる edgeInset で左右を floating させる（ボタン行と揃う）。
    .padding(.horizontal, Screen.edgeInset)
  }

  private var seekTrack: some View {
    Capsule()
      .fill(.quaternary)
      .frame(height: 4)
      .overlay(alignment: .leading) {
        GeometryReader { g in
          Capsule()
            .fill(Color.accentColor)
            .frame(width: g.size.width * progress)
        }
      }
      .frame(maxWidth: .infinity)
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

  /// バー（カプセル）を画面角と同心に floating させるための edgeInset。
  /// abceed-ios RichAudioBar 準拠: 画面角半径から capsule 半径 (= バー高さ / 2) を引く。最小 16pt。
  /// 左右・下端の floating マージンに共通で使う。
  static let barHeight: CGFloat = 56
  static var edgeInset: CGFloat {
    max(displayCornerRadius - barHeight / 2, 16)
  }
}

#Preview {
  ContentView()
}
