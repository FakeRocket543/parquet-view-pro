// Zoomable Scroll View
// Implements pinch-to-zoom with auto-fit (like Numbers)
// SM-X: Zoom Feature

import SwiftUI

struct ZoomableScrollView<Content: View>: View {
    @Binding var currentZoom: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let content: Content
    
    @State private var steadyZoom: CGFloat = 1.0
    @State private var gestureZoom: CGFloat = 1.0
    
    init(
        currentZoom: Binding<CGFloat>,
        minZoom: CGFloat,
        maxZoom: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self._currentZoom = currentZoom
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                content
                    // ????? scaleEffect??? fixedSize
                    // ?? LazyVStack ???????
                    // ?????????????????
                    .scaleEffect(currentZoom, anchor: .center)
            }
            .clipped()
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newZoom = steadyZoom * value
                        gestureZoom = value
                        currentZoom = min(max(newZoom, minZoom), maxZoom)
                    }
                    .onEnded { value in
                        steadyZoom = currentZoom
                        gestureZoom = 1.0
                    }
            )
            .onAppear {
                steadyZoom = currentZoom
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZoomableScrollView(
        currentZoom: .constant(1.0),
        minZoom: 0.5,
        maxZoom: 3.0
    ) {
        VStack {
            ForEach(0..<20) { i in
                HStack {
                    ForEach(0..<10) { j in
                        Text("[\(i),\(j)]")
                            .frame(width: 80, height: 30)
                            .border(Color.gray)
                    }
                }
            }
        }
    }
    .frame(width: 800, height: 600)
}
