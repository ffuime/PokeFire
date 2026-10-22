import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    @State private var drawerOpen = false
    @State private var dragX: CGFloat = 0
    @State private var dragging = false

    var body: some View {
        mainContent
        .overlay(alignment: .top) {
            ToastView()
        }
        .overlay {
            if model.isLoadingShare {
                LoadingOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isLoadingShare)
    }

    private var mainContent: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width * 0.8, 340)
            let base: CGFloat = drawerOpen ? width : 0
            let offset = max(0, min(width, base + dragX))
            let progress = width > 0 ? offset / width : 0

            ZStack(alignment: .topLeading) {
                Palette.card.ignoresSafeArea()

                HistoryDrawer(
                    isOpen: drawerOpen,
                    close: { setDrawer(false) },
                    dragChanged: { dx in
                        dragging = true
                        dragX = min(0, dx)
                    },
                    dragEnded: { dx, projected in
                        dragging = false
                        setDrawer(!(projected < -width * 0.35 || dx < -width * 0.4))
                    }
                )
                    .frame(width: width)
                    .offset(x: (progress - 1) * width * 0.3)
                    .opacity(0.4 + 0.6 * progress)

                Group {
                    if stats.mode == .box {
                        BoxRoot()
                            .transition(.opacity)
                    } else {
                        MainScreen(openDrawer: { setDrawer(true) })
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: stats.mode == .box)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .allowsHitTesting(progress < 0.01)
                    .overlay {
                        Color.black
                            .opacity(0.14 * progress)
                            .ignoresSafeArea()
                            .allowsHitTesting(progress > 0.01)
                            .onTapGesture { setDrawer(false) }
                    }
                    .mask {
                        RoundedRectangle(cornerRadius: 44 * progress, style: .continuous)
                            .ignoresSafeArea()
                    }
                    .shadow(color: .black.opacity(0.12 * progress), radius: 24, x: -4)
                    .offset(x: offset)
                    .simultaneousGesture(closeGesture(width: width), including: drawerOpen ? .all : .none)

                if !drawerOpen, stats.mode != .box || stats.boxAtRoot {
                    Color.clear
                        .frame(width: 14)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(openGesture(width: width))
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .animation(dragging ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: drawerOpen)
            .animation(dragging ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: dragX)
        }
    }

    private func setDrawer(_ open: Bool) {
        guard open != drawerOpen || dragX != 0 else { return }
        if open != drawerOpen { Haptics.play(open ? .light : .soft) }
        dragging = false
        dragX = 0
        drawerOpen = open
    }

    private func openGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                dragging = true
                dragX = max(0, value.translation.width)
            }
            .onEnded { value in
                dragging = false
                let projected = value.predictedEndTranslation.width
                setDrawer(projected > width * 0.4 || value.translation.width > width * 0.5)
            }
    }

    private func closeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragging = true
                dragX = min(0, value.translation.width)
            }
            .onEnded { value in
                dragging = false
                let projected = value.predictedEndTranslation.width
                setDrawer(!(projected < -width * 0.35 || value.translation.width < -width * 0.4))
            }
    }
}

struct ToastView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            if let toast = model.toast {
                Text(toast.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: Capsule())
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toast.id)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.toast)
        .allowsHitTesting(false)
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.08).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("共有された条件を読み込み中…")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.secondary)
            }
            .padding(24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }
}
