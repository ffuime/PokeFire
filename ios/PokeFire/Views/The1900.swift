import CoreText
import SwiftUI

struct T1900Word: Identifiable, Equatable {
    var id: Int { no }
    let no: Int
    let word: String
    let meaning: String
    let quiz: String
}

struct T1900Scope: Equatable {
    let key: String
    let label: String
    let range: String
    let words: [T1900Word]
}

enum T1900Store {
    private static let bestKey = "the1900-best"
    private static let lastKey = "the1900-last"
    private static let recentWeight = 2.0 / 3.0

    static let words: [T1900Word] = {
        guard
            let url = Bundle.main.url(forResource: "the1900", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let rows = try? JSONDecoder().decode([[String]].self, from: data)
        else { return [] }
        return rows.enumerated().compactMap { index, row in
            guard row.count >= 2 else { return nil }
            return T1900Word(no: index + 1, word: row[0], meaning: row[1], quiz: row.count > 2 ? row[2] : row[1])
        }
    }()

    static let sections: [T1900Scope] = stride(from: 0, to: words.count, by: 100).enumerated().map { number, start in
        let slice = Array(words[start..<min(start + 100, words.count)])
        return T1900Scope(key: String(number + 1), label: "Section \(number + 1)", range: "\(start + 1)–\(start + 100)", words: slice)
    }

    static let all = T1900Scope(key: "all", label: "ALL", range: "1–\(words.count)", words: words)

    static var best: [String: Int] {
        UserDefaults.standard.dictionary(forKey: bestKey) as? [String: Int] ?? [:]
    }

    static func draw(_ words: [T1900Word], count: Int) -> [T1900Word] {
        let recent = Set(UserDefaults.standard.array(forKey: lastKey) as? [Int] ?? [])
        let keyed = words.map { word in
            (word, pow(Double.random(in: 0..<1), recent.contains(word.no) ? 1 / recentWeight : 1))
        }
        return keyed.sorted { $0.1 > $1.1 }.prefix(count).map(\.0).shuffled()
    }

    static func remember(_ words: [T1900Word]) {
        UserDefaults.standard.set(words.map(\.no), forKey: lastKey)
    }

    static func saveBest(_ key: String, _ score: Int) -> Bool {
        var list = best
        if let old = list[key], score <= old { return false }
        list[key] = score
        UserDefaults.standard.set(list, forKey: bestKey)
        return true
    }
}

enum T1900Color {
    static let paper = Color.dynamic(0xFFFFFF, 0x0F1012)
    static let surface = Color.dynamic(0xFFFFFF, 0x1B1D21)
    static let ink = Color.dynamic(0x0B0B0C, 0xF4F5F7)
    static let gray = Color.dynamic(0x6B7280, 0x9CA3AF)
    static let line = Color.dynamic(0xE5E7EB, 0x2E3238)
    static let accent = Color.dynamic(0x0A8FDC, 0x38ACEE)
    static let accentDeep = Color.dynamic(0x0672B3, 0x7CC9F5)
    static let accentSoft = Color.dynamic(0xE4F4FD, 0x12354A)
    static let wrong = Color.dynamic(0xE5484D, 0xF2666A)
    static let wrongSoft = Color.dynamic(0xFDECEC, 0x47191C)
}

struct T1900Outcome: Equatable {
    let correct: Int
    let bonus: Int
    let total: Int
    let isBest: Bool
    let bestKey: String

    var correctPoints: Int { Int((Double(correct) * 80 / Double(total)).rounded()) }
    var bonusPoints: Int { Int((Double(bonus) * 20 / Double(total)).rounded()) }
    var score: Int { correctPoints + bonusPoints }
}

struct The1900View: View {
    private enum Route: Equatable {
        case home
        case test(T1900Scope, Int, UUID)
        case cards(T1900Scope)
        case result(T1900Scope, T1900Outcome)
    }

    private static let tabKey = "the1900-tab"

    @Environment(\.dismiss) private var dismiss
    @State private var route = Route.home
    @State private var tab = UserDefaults.standard.integer(forKey: The1900View.tabKey)
    @State private var revision = 0

    private var isHome: Bool { route == .home }

    private func go(_ next: Route) {
        withAnimation(.snappy(duration: 0.34)) {
            route = next
            if next == .home { revision += 1 }
        }
    }

    var body: some View {
        ZStack {
            T1900Home(
                tab: $tab,
                revision: revision,
                onBack: { dismiss() },
                onTest: { go(.test($0, $1, UUID())) },
                onCards: { go(.cards($0)) }
            )
            .allowsHitTesting(isHome)
            if !isHome {
                ZStack {
                    T1900Color.paper.ignoresSafeArea()
                    screen
                        .transition(.opacity)
                }
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
        }
        .onChange(of: tab) { _, value in
            UserDefaults.standard.set(value, forKey: The1900View.tabKey)
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch route {
        case .home:
            EmptyView()
        case .test(let scope, let count, let run):
            T1900TestView(
                scope: scope,
                total: count,
                onClose: { go(.home) },
                onFinish: { go(.result(scope, $0)) }
            )
            .id(run)
        case .cards(let scope):
            T1900CardsView(scope: scope) { go(.home) }
        case .result(let scope, let outcome):
            T1900ResultView(
                scope: scope,
                outcome: outcome,
                onRetry: { go(.test(scope, outcome.total, UUID())) },
                onList: { go(.home) }
            )
        }
    }
}

private struct T1900BarButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.play(.light)
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(T1900Color.ink)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(label)
    }
}

private struct T1900Bar<Trailing: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        ZStack {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(T1900Color.ink)
            HStack {
                T1900BarButton(symbol: "xmark", label: "閉じる", action: onClose)
                Spacer()
                trailing()
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(T1900Color.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

private struct T1900Home: View {
    @Binding var tab: Int
    let revision: Int
    let onBack: () -> Void
    let onTest: (T1900Scope, Int) -> Void
    let onCards: (T1900Scope) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 14) {
                T1900BarButton(symbol: "chevron.left", label: "戻る", action: onBack)
                HStack(spacing: 0) {
                    Text("THE")
                        .foregroundStyle(T1900Color.ink)
                    Text("1900")
                        .foregroundStyle(T1900Color.accent)
                }
                .font(.system(size: 34, weight: .heavy))
            }
            .padding(.horizontal, 20)
            TabView(selection: $tab) {
                Tab("テスト", systemImage: "checklist", value: 0) {
                    T1900List(test: true, revision: revision, onTest: onTest, onCards: onCards)
                }
                Tab("カード", systemImage: "rectangle.stack", value: 1) {
                    T1900List(test: false, revision: revision, onTest: onTest, onCards: onCards)
                }
            }
            .tint(T1900Color.accent)
        }
        .padding(.top, 6)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

private final class T1900ScrollTracker {
    var offset: CGFloat = 0
    var restored = false
}

private struct T1900List: View {
    private static let rowHeight: CGFloat = 65

    let test: Bool
    let revision: Int
    let onTest: (T1900Scope, Int) -> Void
    let onCards: (T1900Scope) -> Void

    @State private var tracker = T1900ScrollTracker()

    private var scrollKey: String { test ? "the1900-scroll-test" : "the1900-scroll-cards" }
    private var scopes: [T1900Scope] { test ? [T1900Store.all] + T1900Store.sections : T1900Store.sections }

    var body: some View {
        let best = T1900Store.best
        ScrollViewReader { proxy in
            List(scopes, id: \.key) { scope in
                Button {
                    Haptics.play(.light)
                    if test { onTest(scope, T1900TestView.standardCount) } else { onCards(scope) }
                } label: {
                    row(scope, score: best[scope.key])
                }
                .id(scope.key)
                .contextMenu {
                    if test {
                        Button {
                            onTest(scope, T1900TestView.longCount)
                        } label: {
                            Label("100問モードで開始", systemImage: "text.badge.checkmark")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, value in
                tracker.offset = value
            }
            .onAppear {
                guard !tracker.restored else { return }
                tracker.restored = true
                let saved = UserDefaults.standard.double(forKey: scrollKey)
                let index = min(scopes.count - 1, Int(saved / Self.rowHeight))
                guard index > 0 else { return }
                let key = scopes[index].key
                DispatchQueue.main.async { proxy.scrollTo(key, anchor: .top) }
            }
            .onDisappear {
                UserDefaults.standard.set(Double(tracker.offset), forKey: scrollKey)
            }
        }
    }

    private func row(_ scope: T1900Scope, score: Int?) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(scope.label)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(T1900Color.ink)
                Text(scope.range)
                    .font(.caption)
                    .foregroundStyle(T1900Color.gray)
            }
            Spacer()
            if test {
                VStack(alignment: .trailing, spacing: 5) {
                    Text(score.map(String.init) ?? "–")
                        .font(.headline.weight(.heavy))
                        .monospacedDigit()
                        .foregroundStyle(T1900Color.ink)
                    ZStack(alignment: .leading) {
                        Capsule().fill(T1900Color.line)
                        Capsule()
                            .fill(T1900Color.accent)
                            .frame(width: 92 * CGFloat(score ?? 0) / 100)
                    }
                    .frame(width: 92, height: 5)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(T1900Color.gray)
            }
        }
        .frame(minHeight: 52)
    }
}

struct T1900Question {
    let word: T1900Word
    let toJapanese: Bool
    let options: [T1900Word]
    let answer: Int
    var picked: Int?
    var correct = false
    var bonus = false
    var rest = 0.0

    init(_ word: T1900Word, toJapanese: Bool, pool: [T1900Word]) {
        var seen: Set<String> = [word.quiz]
        var options = [word]
        for candidate in pool.shuffled() where options.count < 4 && !seen.contains(candidate.quiz) {
            seen.insert(candidate.quiz)
            options.append(candidate)
        }
        let mixed = options.shuffled()
        self.word = word
        self.toJapanese = toJapanese
        self.options = mixed
        self.answer = mixed.firstIndex(of: word) ?? 0
    }
}

struct T1900TestView: View {
    static let standardCount = 20
    static let longCount = 100
    private static let bonusSeconds = 5.0

    let scope: T1900Scope
    let total: Int
    let onClose: () -> Void
    let onFinish: (T1900Outcome) -> Void

    @State private var questions: [T1900Question]
    @State private var head = 0
    @State private var current = 0
    @State private var startedAt = Date()
    @State private var count: Int? = 3
    @State private var forward = true
    @State private var verdict: Bool?
    @State private var bonusShown = false
    @State private var confirmQuit = false
    @State private var autoNext: Task<Void, Never>?

    init(scope: T1900Scope, total: Int, onClose: @escaping () -> Void, onFinish: @escaping (T1900Outcome) -> Void) {
        self.scope = scope
        self.total = total
        self.onClose = onClose
        self.onFinish = onFinish
        let picked = T1900Store.draw(scope.words, count: total)
        let directions = picked.indices.map { $0 < picked.count / 2 }.shuffled()
        _questions = State(initialValue: picked.enumerated().map { index, word in
            T1900Question(word, toJapanese: directions[index], pool: scope.words)
        })
    }

    private var started: Bool { count == nil }
    private var waitingNext: Bool { current == head && questions[head].picked != nil }

    private func rest(_ now: Date) -> Double {
        guard started else { return 1 }
        let question = questions[head]
        if question.picked != nil { return question.rest }
        return max(0, 1 - now.timeIntervalSince(startedAt) / Self.bonusSeconds)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                T1900Bar(title: scope.label, onClose: close) {
                    Text("\(questions.filter { $0.picked != nil }.count)/\(questions.count)")
                }
                timer
                ZStack {
                    if let count {
                        Text("\(count)")
                            .font(.system(size: 96, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(T1900Color.accent)
                            .id(count)
                            .transition(.scale(scale: 1.4).combined(with: .opacity))
                    } else {
                        page(current)
                            .id(current)
                            .transition(.asymmetric(
                                insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                footer
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if started, waitingNext, !confirmQuit { advance() }
            }
            if let verdict {
                VStack(spacing: 12) {
                    T1900Verdict(correct: verdict)
                    if bonusShown {
                        Label("Time Bonus +1", systemImage: "bolt.fill")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(T1900Color.accentDeep)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(T1900Color.accentSoft, in: Capsule())
                    }
                }
                .allowsHitTesting(false)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .alert("テストを終了しますか？", isPresented: $confirmQuit) {
            Button("続ける", role: .cancel) {
                if waitingNext { arm() }
            }
            Button("終了する", role: .destructive) { onClose() }
        } message: {
            Text("結果は記録されません。")
        }
        .task { await runCountdown() }
        .onDisappear { disarm() }
    }

    private var timer: some View {
        VStack(alignment: .leading, spacing: 6) {
            TimelineView(.animation(paused: !started || questions[head].picked != nil)) { context in
                let value = rest(context.date)
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(T1900Color.line)
                            Capsule()
                                .fill(T1900Color.accent)
                                .frame(width: geometry.size.width * value)
                        }
                    }
                    .frame(height: 6)
                    Label("Time Bonus", systemImage: "bolt.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(T1900Color.accentDeep)
                        .opacity(value == 0 ? 0.3 : 1)
                        .animation(.easeOut(duration: 0.4), value: value == 0)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private func page(_ index: Int) -> some View {
        let question = questions[index]
        let prompt = question.toJapanese ? question.word.word : question.word.quiz
        return VStack(spacing: 16) {
            Spacer(minLength: 8)
            Text(prompt)
                .font(question.toJapanese ? .system(size: 46, weight: .heavy) : .system(size: prompt.count > 22 ? 22 : 28, weight: .bold))
                .foregroundStyle(T1900Color.ink)
                .multilineTextAlignment(.center)
                .lineLimit(question.toJapanese ? 1 : 5)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 20)
            Spacer(minLength: 8)
            VStack(spacing: 10) {
                ForEach(question.options.indices, id: \.self) { choice in
                    choiceButton(question, choice)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func choiceButton(_ question: T1900Question, _ index: Int) -> some View {
        let option = question.options[index]
        let text = question.toJapanese ? option.quiz : option.word
        let answered = question.picked != nil
        let isAnswer = index == question.answer
        let isPicked = index == question.picked
        let tint: Color = !answered ? T1900Color.line : isAnswer ? T1900Color.accent : isPicked ? T1900Color.wrong : T1900Color.line
        let fill: Color = answered && isAnswer ? T1900Color.accentSoft : answered && isPicked ? T1900Color.wrongSoft : T1900Color.surface
        return Button {
            choose(index)
        } label: {
            HStack(spacing: 8) {
                Text(text)
                    .font(question.toJapanese ? .system(size: text.count > 30 ? 13 : 15, weight: .bold) : .system(size: 18, weight: .bold))
                    .foregroundStyle(T1900Color.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Image(systemName: isAnswer ? "circle" : "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                    .opacity(answered && (isAnswer || isPicked) ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint, lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .allowsHitTesting(!answered)
        .opacity(answered && !isAnswer && !isPicked ? 0.45 : 1)
    }

    private var footer: some View {
        HStack {
            stepButton("前の問題へ", symbol: "chevron.left", enabled: started && current > 0, leading: true) {
                disarm()
                show(current - 1, forward: false)
            }
            Spacer()
            Text(started && waitingNext ? "Tap to Continue" : "")
                .font(.caption.weight(.bold))
                .foregroundStyle(T1900Color.gray)
            Spacer()
            stepButton("次の問題へ", symbol: "chevron.right", enabled: started && current < head, leading: false) {
                show(current + 1, forward: true)
                if current == head, questions[head].picked != nil { arm() }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
    }

    private func stepButton(_ title: String, symbol: String, enabled: Bool, leading: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.play(.light)
            action()
        } label: {
            HStack(spacing: 2) {
                if leading { Image(systemName: symbol) }
                Text(title)
                if !leading { Image(systemName: symbol) }
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(T1900Color.ink)
            .padding(.horizontal, 8)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    private func runCountdown() async {
        for value in [3, 2, 1] {
            withAnimation(.snappy(duration: 0.12)) { count = value }
            Haptics.play(.rigid)
            try? await Task.sleep(for: .milliseconds(320))
            if Task.isCancelled { return }
        }
        withAnimation(.snappy(duration: 0.2)) { count = nil }
        startedAt = Date()
    }

    private func close() {
        if started {
            disarm()
            confirmQuit = true
        } else {
            onClose()
        }
    }

    private func arm() {
        disarm()
        autoNext = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { advance() }
        }
    }

    private func disarm() {
        autoNext?.cancel()
        autoNext = nil
    }

    private func show(_ index: Int, forward: Bool) {
        self.forward = forward
        withAnimation(.snappy(duration: 0.26)) {
            verdict = nil
            bonusShown = false
            current = index
        }
    }

    private func choose(_ index: Int) {
        guard started, current == head, questions[head].picked == nil else { return }
        let elapsed = Date().timeIntervalSince(startedAt)
        let correct = index == questions[head].answer
        let bonus = correct && elapsed <= Self.bonusSeconds
        questions[head].picked = index
        questions[head].correct = correct
        questions[head].bonus = bonus
        questions[head].rest = max(0, 1 - elapsed / Self.bonusSeconds)
        Haptics.play(correct ? .success : .error)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            verdict = correct
            bonusShown = bonus
        }
        arm()
    }

    private func advance() {
        disarm()
        guard head < questions.count - 1 else { return finish() }
        head += 1
        startedAt = Date()
        show(head, forward: true)
    }

    private func finish() {
        let correct = questions.filter(\.correct).count
        let bonus = questions.filter(\.bonus).count
        let key = total == Self.standardCount ? scope.key : "\(scope.key)-\(total)"
        let draft = T1900Outcome(correct: correct, bonus: bonus, total: questions.count, isBest: false, bestKey: key)
        let isBest = T1900Store.saveBest(key, draft.score)
        T1900Store.remember(questions.map(\.word))
        onFinish(T1900Outcome(correct: correct, bonus: bonus, total: questions.count, isBest: isBest, bestKey: key))
    }
}

private struct T1900Verdict: View {
    let correct: Bool

    var body: some View {
        ZStack {
            if correct {
                Circle()
                    .strokeBorder(T1900Color.accent, lineWidth: 30)
            } else {
                Capsule()
                    .fill(T1900Color.wrong)
                    .frame(width: 30, height: 196)
                    .rotationEffect(.degrees(45))
                Capsule()
                    .fill(T1900Color.wrong)
                    .frame(width: 30, height: 196)
                    .rotationEffect(.degrees(-45))
            }
        }
        .frame(width: 164, height: 164)
    }
}

private struct T1900CountText: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))")
    }
}

private struct T1900ResultView: View {
    let scope: T1900Scope
    let outcome: T1900Outcome
    let onRetry: () -> Void
    let onList: () -> Void

    @State private var progress = 0.0

    var body: some View {
        VStack(spacing: 0) {
            Text(outcome.total == T1900TestView.standardCount ? scope.label : "\(scope.label)・\(outcome.total)問")
                .font(.headline.weight(.heavy))
                .foregroundStyle(T1900Color.ink)
                .frame(height: 56)
            Spacer()
            Text("達成度")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(T1900Color.gray)
            ZStack {
                Circle().stroke(T1900Color.line, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress / 100)
                    .stroke(T1900Color.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    T1900CountText(value: progress)
                        .font(.system(size: 64, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(T1900Color.ink)
                    Text("/ 100")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(T1900Color.gray)
                }
            }
            .frame(width: 200, height: 200)
            .padding(.vertical, 18)
            Text(outcome.isBest ? "自己ベスト更新" : "自己ベスト \(T1900Store.best[outcome.bestKey] ?? outcome.score)")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(outcome.isBest ? T1900Color.accentDeep : T1900Color.gray)
            VStack(spacing: 0) {
                tally("Correct", "\(outcome.correct) / \(outcome.total)", "\(outcome.correctPoints) pt")
                tally("Time Bonus", "\(outcome.bonus) / \(outcome.total)", "\(outcome.bonusPoints) pt")
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            Spacer()
            VStack(spacing: 10) {
                Button(action: onRetry) {
                    Label("もう一度", systemImage: "arrow.counterclockwise")
                        .font(.body.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.glassProminent)
                .tint(T1900Color.accent)
                Button(action: onList) {
                    Label("一覧へ", systemImage: "list.bullet")
                        .font(.body.weight(.bold))
                        .foregroundStyle(T1900Color.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.9)) { progress = Double(outcome.score) }
        }
    }

    private func tally(_ title: String, _ value: String, _ points: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(T1900Color.gray)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(T1900Color.ink)
            Text(points)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(T1900Color.gray)
                .frame(width: 44, alignment: .trailing)
        }
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            Rectangle().fill(T1900Color.line).frame(height: 1)
        }
    }
}

private struct T1900Reveal: Shape {
    var radius: CGFloat
    let inset: CGFloat

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)
        return Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

private struct T1900CardsView: View {
    private static let dotRadius: CGFloat = 30
    private static let dotInset: CGFloat = 50
    private static let offScreen: CGFloat = 1.35
    private static let tilt = 16.0
    private static let peek: CGFloat = 13
    private static let peekScale: CGFloat = 0.05

    let scope: T1900Scope
    let onClose: () -> Void

    @State private var order: [T1900Word]
    @State private var index = 0
    @State private var nextProgress: CGFloat = 0
    @State private var backProgress: CGFloat = 0
    @State private var busy = false
    @State private var held = false
    @State private var shuffled = false
    @State private var riffle = false

    init(scope: T1900Scope, onClose: @escaping () -> Void) {
        self.scope = scope
        self.onClose = onClose
        _order = State(initialValue: scope.words)
    }

    private func word(_ offset: Int) -> T1900Word {
        let count = order.count
        return order[((index + offset) % count + count) % count]
    }

    private func slot(_ position: CGFloat) -> (y: CGFloat, scale: CGFloat) {
        (position * Self.peek, 1 - position * Self.peekScale)
    }

    var body: some View {
        VStack(spacing: 0) {
            T1900Bar(title: scope.label, onClose: onClose) {
                Text("\(index + 1)/\(order.count)")
            }
            .zIndex(5)
            GeometryReader { geometry in
                deck(geometry.size)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 54)
        }
    }

    @ViewBuilder
    private func deck(_ size: CGSize) -> some View {
        let width = max(1, size.width)
        ZStack {
            if backProgress == 0 {
                card(word(3), size: size, active: false)
                    .opacity(nextProgress)
                    .modifier(T1900Slot(slot: slot(max(2, 3 - rise(width: width)))))
                    .zIndex(0)
            }
            card(word(2), size: size, active: false)
                .opacity(1 - backProgress)
                .modifier(T1900Slot(slot: slot(2 - rise(width: width) + backProgress)))
                .modifier(T1900Riffle(active: riffle, x: 0, y: -0.05, angle: 0, size: size))
                .zIndex(1)
            card(word(1), size: size, active: false)
                .modifier(T1900Slot(slot: slot(1 - rise(width: width) + backProgress)))
                .modifier(T1900Riffle(active: riffle, x: 0.34, y: 0, angle: 7, size: size))
                .zIndex(2)
            card(word(0), size: size, active: true)
                .modifier(T1900Slot(slot: slot(backProgress)))
                .offset(x: -nextProgress * Self.offScreen * width)
                .rotationEffect(.degrees(-Self.tilt * nextProgress))
                .modifier(T1900Riffle(active: riffle, x: -0.34, y: 0, angle: -7, size: size))
                .zIndex(3)
            if backProgress > 0 {
                card(word(-1), size: size, active: false)
                    .offset(x: -(1 - backProgress) * Self.offScreen * width)
                    .rotationEffect(.degrees(-Self.tilt * (1 - backProgress)))
                    .zIndex(4)
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .gesture(drag(width: width))
    }

    private func rise(width: CGFloat) -> CGFloat {
        min(1, nextProgress * Self.offScreen)
    }

    private func card(_ word: T1900Word, size: CGSize, active: Bool) -> some View {
        let reach = hypot(size.width - Self.dotInset, size.height - Self.dotInset) + 2
        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(T1900Color.surface)
            cardFront(word, width: size.width - 48)
            ZStack(alignment: .topLeading) {
                T1900Color.ink
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(word.meaning.components(separatedBy: "；"), id: \.self) { part in
                        Text(part)
                    }
                }
                .font(.system(size: word.meaning.count > 40 ? 20 : 25, weight: .heavy))
                .foregroundStyle(T1900Color.paper)
                .lineSpacing(3)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 96)
                number(word, color: T1900Color.accentDeep)
            }
            .clipShape(T1900Reveal(radius: active && held ? reach : Self.dotRadius, inset: Self.dotInset))
            .allowsHitTesting(false)
            if active {
                controls
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(T1900Color.line, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.06), radius: 9, y: 6)
    }

    private func cardFront(_ word: T1900Word, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            T1900HyphenWord(text: word.word, width: max(1, width))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 96)
            number(word, color: T1900Color.accentDeep)
        }
    }

    private func number(_ word: T1900Word, color: Color) -> some View {
        Text("No. \(word.no)")
            .font(.footnote.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.top, 22)
            .padding(.leading, 24)
    }

    private var controls: some View {
        ZStack(alignment: .bottom) {
            HStack {
                Button(action: toggleShuffle) {
                    Label("Shuffle", systemImage: "shuffle")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(shuffled ? T1900Color.accentDeep : T1900Color.ink)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(shuffled ? T1900Color.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                T1900TouchArea { setHeld($0) }
                    .frame(width: 76, height: 76)
                    .accessibilityLabel("長押しで訳を表示")
                    .accessibilityAddTraits(.isButton)
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func setHeld(_ value: Bool) {
        guard value != held else { return }
        if value { Haptics.play(.rigid) }
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: value ? 0.55 : 0.4)) { held = value }
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { gesture in
                guard !busy else { return }
                setHeld(false)
                let dx = gesture.translation.width
                if dx < 0 {
                    backProgress = 0
                    nextProgress = min(1, -dx / (width * Self.offScreen))
                } else {
                    nextProgress = 0
                    backProgress = min(1, dx / width)
                }
            }
            .onEnded { gesture in
                guard !busy else { return }
                let dx = gesture.translation.width
                let flick = gesture.predictedEndTranslation.width
                let decided = abs(dx) >= 72 || (abs(dx) >= 16 && abs(flick) >= 160 && flick * dx > 0)
                if dx < 0 {
                    decided ? throwNext() : settle()
                } else {
                    decided ? landBack() : settle()
                }
            }
    }

    private func settle() {
        withAnimation(.snappy(duration: 0.28)) {
            nextProgress = 0
            backProgress = 0
        }
    }

    private func throwNext() {
        busy = true
        Haptics.play(.light)
        withAnimation(.timingCurve(0.3, 0.6, 0.4, 1, duration: 0.28)) {
            nextProgress = 1
        } completion: {
            index = (index + 1) % order.count
            nextProgress = 0
            busy = false
        }
    }

    private func landBack() {
        busy = true
        Haptics.play(.light)
        withAnimation(.timingCurve(0.3, 0.6, 0.4, 1, duration: 0.28)) {
            backProgress = 1
        } completion: {
            index = (index - 1 + order.count) % order.count
            backProgress = 0
            busy = false
        }
    }

    private func toggleShuffle() {
        guard !busy else { return }
        busy = true
        Haptics.play(.medium)
        let turnOn = !shuffled
        withAnimation(.snappy(duration: 0.2)) { shuffled = turnOn }
        withAnimation(.easeInOut(duration: 0.23)) {
            riffle = true
        } completion: {
            order = turnOn ? scope.words.shuffled() : scope.words
            index = 0
            withAnimation(.easeInOut(duration: 0.23)) {
                riffle = false
            } completion: {
                busy = false
            }
        }
    }
}

private struct T1900TouchArea: UIViewRepresentable {
    let onChange: (Bool) -> Void

    final class TouchView: UIView {
        var onChange: ((Bool) -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            onChange?(true)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            onChange?(false)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            onChange?(false)
        }
    }

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.onChange = onChange
    }
}

private struct T1900HyphenWord: UIViewRepresentable {
    let text: String
    let width: CGFloat

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let large = UIFont.systemFont(ofSize: 56, weight: .heavy)
        let fits = (text as NSString).size(withAttributes: [.font: large]).width <= width
        let style = NSMutableParagraphStyle()
        style.hyphenationFactor = 1
        style.lineHeightMultiple = 0.95
        label.preferredMaxLayoutWidth = width
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: fits ? large : UIFont.systemFont(ofSize: 44, weight: .heavy),
            .foregroundColor: UIColor(T1900Color.ink),
            .paragraphStyle: style,
            NSAttributedString.Key(kCTLanguageAttributeName as String): "en",
        ])
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}

private struct T1900Slot: ViewModifier {
    let slot: (y: CGFloat, scale: CGFloat)

    func body(content: Content) -> some View {
        content
            .scaleEffect(slot.scale, anchor: .bottom)
            .offset(y: slot.y)
    }
}

private struct T1900Riffle: ViewModifier {
    let active: Bool
    let x: CGFloat
    let y: CGFloat
    let angle: Double
    let size: CGSize

    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 0.94 : 1)
            .rotationEffect(.degrees(active ? angle : 0))
            .offset(x: active ? x * size.width : 0, y: active ? y * size.height : 0)
    }
}
