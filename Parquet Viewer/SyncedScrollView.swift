// Synced ScrollView with Frozen Column
// Uses AppKit NSScrollView for reliable scroll synchronization

import SwiftUI
import AppKit

// MARK: - Scroll Position Coordinator
class ScrollPositionCoordinator: ObservableObject {
    @Published var verticalOffset: CGFloat = 0
    
    func updateOffset(_ newOffset: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            self?.verticalOffset = newOffset
        }
    }
}

// MARK: - AppKit ScrollView Wrapper
struct AppKitScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    @ObservedObject var coordinator: ScrollPositionCoordinator
    let showsHorizontalScroller: Bool
    let showsVerticalScroller: Bool
    
    init(
        coordinator: ScrollPositionCoordinator,
        showsHorizontalScroller: Bool = true,
        showsVerticalScroller: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.coordinator = coordinator
        self.showsHorizontalScroller = showsHorizontalScroller
        self.showsVerticalScroller = showsVerticalScroller
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = showsHorizontalScroller
        scrollView.hasVerticalScroller = showsVerticalScroller
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        
        // Create hosting view for SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        hostingView.autoresizingMask = [.width, .height]
        
        scrollView.documentView = hostingView
        
        // Observe scroll notifications
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        
        // Enable live scrolling notifications
        scrollView.contentView.postsBoundsChangedNotifications = true
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Update hosting view if needed
        if let hostingView = nsView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(coordinator: coordinator)
    }
    
    class Coordinator: NSObject {
        let coordinator: ScrollPositionCoordinator
        
        init(coordinator: ScrollPositionCoordinator) {
            self.coordinator = coordinator
        }
        
        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView else { return }
            let offset = clipView.bounds.origin.y
            coordinator.updateOffset(-offset)
        }
    }
}

// MARK: - Data Table with Frozen Row Numbers
struct FrozenColumnDataTable: View {
    let columns: [String]
    let rows: [[String]]
    let isLoadingMore: Bool
    let hasMoreData: Bool
    let onLoadMore: () -> Void
    let rowHeight: CGFloat = 28
    let columnWidth: CGFloat = 180
    
    @StateObject private var scrollCoordinator = ScrollPositionCoordinator()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                // Row number header
                Text("#")
                    .frame(width: 60, height: 32)
                    .background(Color(NSColor.controlBackgroundColor))
                    .border(Color(NSColor.separatorColor), width: 0.5)
                
                // Column headers (scrollable)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                            Text(column)
                                .frame(width: columnWidth, height: 32)
                                .background(Color(NSColor.controlBackgroundColor))
                                .border(Color(NSColor.separatorColor), width: 0.5)
                        }
                    }
                }
            }
            
            // Data area
            GeometryReader { geometry in
                HStack(alignment: .top, spacing: 0) {
                    // FROZEN ROW NUMBERS (synced with data scroll)
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(Array(rows.enumerated()), id: \.offset) { index, _ in
                                Text("\(index + 1)")
                                    .frame(width: 60, height: rowHeight)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .border(Color(NSColor.separatorColor), width: 0.5)
                            }
                            
                            if isLoadingMore {
                                ProgressView()
                                    .frame(width: 60, height: rowHeight)
                            }
                        }
                        .offset(y: scrollCoordinator.verticalOffset)
                    }
                    .disabled(true) // Disable user interaction
                    .frame(width: 60)
                    
                    // SCROLLABLE DATA (AppKit NSScrollView for reliable sync)
                    AppKitScrollView(coordinator: scrollCoordinator) {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                                HStack(spacing: 0) {
                                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                                        Text(cell)
                                            .frame(width: columnWidth, height: rowHeight)
                                            .background(Color(NSColor.textBackgroundColor))
                                            .border(Color(NSColor.separatorColor), width: 0.5)
                                    }
                                }
                                .onAppear {
                                    if index == rows.count - 10 && hasMoreData && !isLoadingMore {
                                        onLoadMore()
                                    }
                                }
                            }
                            
                            if isLoadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding()
                                    Text("Loading more...")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .frame(height: rowHeight)
                            }
                        }
                    }
                }
            }
        }
    }
}
