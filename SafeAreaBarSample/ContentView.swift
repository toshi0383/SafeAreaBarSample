import SwiftUI

struct ContentView: View {
  @State private var bottomSafeInset: CGFloat = 0

  @State private var rootViewWidth: CGFloat = 0

  var body: some View {
    GeometryReader { rootProxy in
      Group {
        ScrollViewReader { _ in
          ScrollView {
            ForEach(0..<100) { _ in
              Text("Hello, world!")
            }
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        Color.yellow
          .frame(width: 70, height: 70)
          .allowsHitTesting(true)
          // バーを全幅に広げて blur 背景を画面端まで描く。中身（黄色）は中央のまま。
          .frame(maxWidth: .infinity)
          .background {
            // 自前 blur。`allowsHitTesting(false)` で blur 部分はタッチを透過させ、
            // safeAreaBar の Liquid Glass のように全幅でタッチを奪わないようにする。
            BottomProgressiveBlur()
              .allowsHitTesting(false)
          }
          // SafeArea 下端を無視して blur ごと物理最下端まで押し下げる。
          .padding(.bottom, -bottomSafeInset)
          .ignoresSafeArea(.container, edges: .bottom)
      }
      .onAppear {
        rootViewWidth = rootProxy.size.width
        bottomSafeInset = rootProxy.safeAreaInsets.bottom
      }
      .onChange(of: rootProxy.size.width) { _, newValue in
        rootViewWidth = newValue
      }
      .onChange(of: rootProxy.safeAreaInsets.bottom) { _, newValue in
        bottomSafeInset = newValue
      }
    }
  }
}

/// 下端に向かって濃くなるプログレッシブ blur。
/// `.ultraThinMaterial` を上→下の gradient で mask し、上端は透明・下端は blur の帯にする。
/// タッチ透過は呼び出し側で `.allowsHitTesting(false)` を付けて制御する。
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
  NavigationStack {
    ContentView()
  }
}
