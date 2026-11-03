import SwiftUI

struct SegmentBar: View {
    let count: Int
    let value: Int
    let color: Color
    var height: CGFloat = 32
    var minimum = 0
    var onOverflow: (() -> Void)? = nil
    let onChange: (Int) -> Void

    @State private var dragging = false
    @State private var startedFull = false
    @State private var overflowed = false

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1.5) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(index < minimum ? color.opacity(0.35) : index < value ? color : Palette.track)
                        .scaleEffect(y: dragging && index == value - 1 ? 1.18 : 1)
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let width = max(1, geometry.size.width)
                        if !dragging {
                            startedFull = onOverflow != nil && value == count && gesture.startLocation.x / width > 0.75
                            overflowed = false
                        }
                        dragging = true
                        if startedFull {
                            if gesture.translation.width > 18, !overflowed {
                                overflowed = true
                                Haptics.play(.success)
                                onOverflow?()
                            }
                            if gesture.translation.width > -12 { return }
                            startedFull = false
                        }
                        let ratio = max(0, min(1, gesture.location.x / width))
                        let next = max(minimum, Int(Calc.jsRound(ratio * Double(count))))
                        if next != value {
                            Haptics.play(.selection)
                            onChange(next)
                        }
                    }
                    .onEnded { _ in dragging = false }
            )
        }
        .frame(height: height)
        .animation(.snappy(duration: 0.18), value: value)
        .animation(.snappy(duration: 0.18), value: dragging)
        .accessibilityElement()
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(count, value + 1))
            case .decrement: onChange(max(0, value - 1))
            @unknown default: break
            }
        }
    }
}

struct RatioBar: View {
    let ratio: Double
    let color: Color
    var height: CGFloat = 26
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track)
                Capsule()
                    .fill(color)
                    .overlay(
                        Capsule().fill(LinearGradient(colors: [Color.black.opacity(0.28), Color.black.opacity(0)], startPoint: .leading, endPoint: .trailing))
                    )
                    .frame(width: max(height, geometry.size.width * min(1, max(0, ratio))))
            }
            .frame(height: height)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onChange(max(0, min(1, gesture.location.x / max(1, geometry.size.width))))
                    }
            )
        }
        .frame(height: height)
        .animation(.snappy(duration: 0.2), value: ratio)
    }
}

struct DamageBar: View {
    let sure: Double
    let maybe: Double
    let color: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(color.opacity(0.32))
                    .frame(width: geometry.size.width * min(1, max(0, maybe)))
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * min(1, max(0, sure)))
            }
        }
        .frame(height: height)
        .animation(.snappy(duration: 0.35), value: sure)
        .animation(.snappy(duration: 0.35), value: maybe)
        .animation(.easeInOut(duration: 0.3), value: color)
    }
}

struct CountSegments: View {
    let title: String
    let range: ClosedRange<Int>
    let value: Int
    var openEnded = false
    var tint: Color = Palette.accent
    let onChange: (Int) -> Void

    private func label(_ number: Int) -> String {
        openEnded && number == range.upperBound ? "\(number)+" : "\(number)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.secondary)
                Spacer()
                NumberText(String(value), value: Double(value))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                Text(openEnded && value == range.upperBound ? "回以上" : "回")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.secondary)
            }
            GeometryReader { geometry in
                let numbers = Array(range)
                HStack(spacing: 3) {
                    ForEach(numbers, id: \.self) { number in
                        Text(label(number))
                            .font(.footnote.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(number == value ? Color.white : Palette.ink.opacity(0.7))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background {
                                if number == value {
                                    Capsule().fill(tint)
                                } else {
                                    Capsule().fill(Palette.track.opacity(0.7))
                                }
                            }
                    }
                }
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard !numbers.isEmpty else { return }
                            let ratio = max(0, min(0.9999, gesture.location.x / max(1, geometry.size.width)))
                            let next = numbers[Int(ratio * Double(numbers.count))]
                            if next != value { onChange(next) }
                        }
                )
            }
            .frame(height: 32)
            .animation(.snappy(duration: 0.2), value: value)
        }
    }
}

struct ToggleChip: View {
    let title: String
    let isOn: Bool
    var locked = false
    var tint: Color = Palette.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if locked {
                    Icon(name: "lock", size: 13)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 13)
            .frame(height: 30)
            .foregroundStyle(isOn ? Color.white : tint)
            .background {
                Capsule()
                    .fill(isOn ? tint : Color.clear)
                    .overlay(Capsule().strokeBorder(tint.opacity(isOn ? 0 : 0.55), lineWidth: 1))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(locked)
        .opacity(locked && !isOn ? 0.45 : 1)
        .animation(.snappy(duration: 0.2), value: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct RankControl: View {
    let rank: Int
    let onStep: (Int) -> Void
    let onSet: (Int) -> Void

    private var color: Color {
        rank > 0 ? Palette.rankUp : rank < 0 ? Palette.rankDown : Palette.secondary
    }

    private var text: String {
        rank > 0 ? "+\(rank)" : rank < 0 ? "\(rank)" : "±0"
    }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                onStep(-1)
            } label: {
                Icon(name: "minus", size: 16)
                    .frame(width: 36, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .disabled(rank <= -6)

            Menu {
                Picker("ランク", selection: Binding(get: { rank }, set: { onSet($0) })) {
                    ForEach((-6...6).reversed(), id: \.self) { value in
                        Text(value > 0 ? "+\(value)" : value < 0 ? "\(value)" : "±0").tag(value)
                    }
                }
            } label: {
                NumberText(text, value: Double(rank))
                    .font(.subheadline.weight(.bold))
                    .frame(minWidth: 34)
                    .frame(height: 34)
            }

            Button {
                onStep(1)
            } label: {
                Icon(name: "plus", size: 16)
                    .frame(width: 36, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .disabled(rank >= 6)
        }
        .foregroundStyle(color)
        .background(Capsule().strokeBorder(color.opacity(rank == 0 ? 0.25 : 0.6), lineWidth: 1))
        .animation(.snappy(duration: 0.2), value: rank)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ランク")
        .accessibilityValue(text)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onStep(1)
            case .decrement: onStep(-1)
            @unknown default: break
            }
        }
    }
}

final class ReselectableSegmentedControl: UISegmentedControl {
    var allowsReselect = false
    private var touchStart: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = touches.first?.location(in: self)
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let previous = selectedSegmentIndex
        let start = touchStart
        let end = touches.first?.location(in: self)
        super.touchesEnded(touches, with: event)
        guard allowsReselect, previous == selectedSegmentIndex, let start, let end,
              hypot(end.x - start.x, end.y - start.y) < 10 else { return }
        sendActions(for: .valueChanged)
    }
}

struct NativeSegmented: UIViewRepresentable {
    enum Segment {
        case text(String)
        case image(UIImage)
    }

    let segments: [Segment]
    let selected: Int
    var selectedColor: UIColor?
    var fontSize: CGFloat = 15
    var height: CGFloat = 32
    var allowsReselect = false
    let onChange: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ReselectableSegmentedControl, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? uiView.intrinsicContentSize.width, height: height)
    }

    func makeUIView(context: Context) -> ReselectableSegmentedControl {
        let control = ReselectableSegmentedControl()
        control.allowsReselect = allowsReselect
        for (index, segment) in segments.enumerated() {
            switch segment {
            case .text(let title):
                control.insertSegment(withTitle: title, at: index, animated: false)
            case .image(let image):
                control.insertSegment(with: image, at: index, animated: false)
            }
        }
        control.selectedSegmentIndex = selected
        control.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.defaultLow, for: .vertical)
        style(control)
        return control
    }

    func updateUIView(_ control: ReselectableSegmentedControl, context: Context) {
        context.coordinator.onChange = onChange
        for (index, segment) in segments.enumerated() where index < control.numberOfSegments {
            switch segment {
            case .text(let title):
                if control.titleForSegment(at: index) != title {
                    control.setTitle(title, forSegmentAt: index)
                }
            case .image(let image):
                control.setImage(image, forSegmentAt: index)
            }
        }
        if control.selectedSegmentIndex != selected {
            control.selectedSegmentIndex = selected
        }
        style(control)
    }

    private func style(_ control: UISegmentedControl) {
        var selectedAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: fontSize, weight: .bold)]
        if let selectedColor { selectedAttributes[.foregroundColor] = selectedColor }
        control.setTitleTextAttributes(selectedAttributes, for: .selected)
        control.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: fontSize, weight: .regular), .foregroundColor: UIColor.secondaryLabel], for: .normal)
    }

    @MainActor
    final class Coordinator: NSObject {
        var onChange: (Int) -> Void

        init(onChange: @escaping (Int) -> Void) {
            self.onChange = onChange
        }

        @objc func changed(_ sender: UISegmentedControl) {
            Haptics.play(.selection)
            onChange(sender.selectedSegmentIndex)
        }
    }
}

struct NatureControl: View {
    let nature: Int
    let onChange: (Int) -> Void

    private let options = [9, 10, 11]

    private func color(_ value: Int) -> Color {
        value == 11 ? Palette.rankUp : value == 9 ? Palette.rankDown : Palette.ink
    }

    var body: some View {
        NativeSegmented(
            segments: [.text("×0.9"), .text("×1.0"), .text("×1.1")],
            selected: options.firstIndex(of: nature) ?? 1,
            selectedColor: UIColor(color(nature)),
            height: 40
        ) { index in
            let value = options[max(0, min(options.count - 1, index))]
            if value != nature { onChange(value) }
        }
        .frame(width: 186, height: 40)
        .accessibilityLabel("性格補正")
    }
}

struct PillLabel: View {
    let title: String
    let value: String
    var unit = ""

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(Palette.accent.opacity(0.65))
            NumberText(value, value: Double(value))
                .fontWeight(.bold)
            if !unit.isEmpty {
                Text(unit)
            }
        }
        .font(.subheadline)
        .foregroundStyle(Palette.accent)
        .padding(.horizontal, 13)
        .frame(height: 30)
        .background(Capsule().fill(Palette.card))
        .overlay(Capsule().strokeBorder(Palette.accent, lineWidth: 1))
        .contentShape(Capsule())
    }
}

struct CountPill: View {
    let title: String
    let range: ClosedRange<Int>
    let value: Int
    var openEnded = false
    var unit = "回"
    var pickerRange: ClosedRange<Int>?
    let onChange: (Int) -> Void

    @State private var picking = false
    @State private var width: CGFloat = 1

    private var upper: Int { (pickerRange ?? range).upperBound }

    private func label(_ number: Int) -> String {
        openEnded && number == upper ? "\(number)+" : "\(number)"
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(Palette.accent.opacity(0.65))
            NumberText(String(value), value: Double(value))
                .fontWeight(.bold)
            Text(openEnded && value == upper ? "\(unit)以上" : unit)
        }
        .font(.subheadline)
        .foregroundStyle(Palette.accent)
        .padding(.horizontal, 13)
        .frame(height: 30)
        .background(Capsule().fill(Palette.card))
        .overlay(Capsule().strokeBorder(Palette.accent, lineWidth: 1))
        .contentShape(Capsule())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = max(1, $0) }
        .onTapGesture {
            Haptics.play(.light)
            picking = true
        }
        .gesture(HorizontalPan(onChanged: { location in
            let numbers = Array(range)
            guard !numbers.isEmpty else { return }
            let ratio = max(0, min(0.9999, location.x / width))
            let next = numbers[Int(ratio * Double(numbers.count))]
            if next != value {
                Haptics.play(.selection)
                onChange(next)
            }
        }))
        .popover(isPresented: $picking) {
            if let pickerRange {
                Picker(title, selection: Binding(get: { value }, set: { onChange($0) })) {
                    ForEach(Array(pickerRange), id: \.self) { number in
                        Text(label(number)).tag(number)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 180, height: 180)
                .presentationCompactAdaptation(.popover)
            } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.secondary)
                HStack(spacing: 6) {
                    ForEach(Array(range), id: \.self) { number in
                        Button {
                            onChange(number)
                            picking = false
                        } label: {
                            Text(label(number))
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(number == value ? Color.white : Palette.accent)
                                .frame(minWidth: 34, minHeight: 34)
                                .background(Circle().fill(number == value ? Palette.accent : Palette.accent.opacity(0.1)))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(14)
            .presentationCompactAdaptation(.popover)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(value)回")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(range.upperBound, value + 1))
            case .decrement: onChange(max(range.lowerBound, value - 1))
            @unknown default: break
            }
        }
    }
}

struct CircleIconButton: View {
    let icon: String
    var size: CGFloat = 20
    var tint: Color = Palette.ink
    var label: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Icon(name: icon, size: size)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(label)
    }
}

struct SelectButton: View {
    let text: String
    var placeholder = "なし"
    var sprite: String?
    var height: CGFloat = 48
    var font: Font = .body
    var translucent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let sprite, BundleSprite.image(sprite) != nil {
                    SpriteIcon(name: sprite, size: 26)
                } else {
                    Icon(name: "search", size: 18)
                        .foregroundStyle(Color(hex: 0xAAAAAA))
                        .frame(width: 26)
                }
                Text(text.isEmpty ? placeholder : text)
                    .font(font)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
                Icon(name: "chevron_down", size: 16)
                    .foregroundStyle(Palette.secondary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .frame(height: height)
            .background {
                if translucent {
                    ZStack {
                        UnevenBox().fill(.ultraThinMaterial)
                        UnevenBox().fill(Palette.card.opacity(0.6))
                    }
                } else {
                    UnevenBox().fill(Palette.card)
                }
            }
            .overlay(UnevenBox().stroke(Palette.separator.opacity(translucent ? 0.7 : 1), lineWidth: 1))
            .contentShape(UnevenBox())
        }
        .buttonStyle(PressableStyle())
        .animation(.snappy(duration: 0.2), value: text)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
