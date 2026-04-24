//
//  LiveCaptionView.swift
//  lecsy
//
//  Apple Music 時間同期歌詞のデザイン言語を live transcription に移植。
//
//  原則:
//   1. 28pt rounded semibold のアクティブ行が画面を支配。
//      過去行は depth に応じて縮小・opacity decay。
//   2. アクティブ行はスクロール上 y=0.22 に pin（顔の高さに置く）。
//      下に 180pt の空白スペーサーを持たせてスクロール余地と
//      "呼吸" の空間を両立する。
//   3. interim は単一 Text + `.contentTransition(.opacity)` で
//      クロスフェード更新。ForEach で単語を keyed にするより滑らか。
//   4. 上端だけ薄い fade マスクで edge を柔らかくする（hard な角を隠す程度、
//      content を見えなくはしない）。
//   5. `.ultraThinMaterial` 背景 + 柔らかいシャドウで浮遊感。
//   6. 新しい final 毎に light haptic (Apple 音声入力系の作法)。
//

import SwiftUI
import UIKit
import Combine

struct LiveCaptionView: View {

    @ObservedObject var coordinator: TranscriptionCoordinator
    // Dad 2026-04-24: 学会で認識されているか不安 → 音声レベルで "届いているが
    // 認識されていない" と "そもそも音が入っていない" を区別する。
    @ObservedObject private var recording: RecordingService = RecordingService.shared
    @State private var pulse: Bool = false
    @State private var cursorOn: Bool = true
    @State private var lastHapticSegmentCount: Int = 0
    @State private var lastActivityAt: Date = Date()
    @State private var lowAudioSince: Date?
    // 1s ヒートビート。phase 計算で経過時間を使うため、Published でない時間軸
    // 依存を View に再描画させるトリガとして使う。
    @State private var heartbeatTick: Int = 0

    /// 直近の認識アクティビティから何秒経ったかを判断するためのクールダウン秒数。
    /// これを超えると "recognizing" から "waiting" に落ちる。Deepgram は interim を
    /// 100-200ms 間隔で投げるので 5s は充分な余裕。
    private let recognitionStaleSeconds: TimeInterval = 5

    /// 「音声は届いているが、そもそも誰も喋っていない (=無音)」と判断するまでの秒数。
    /// 初回録音開始直後から 10 秒は初期状態扱いで amber に落とさない。
    private let waitingForSpeechSeconds: TimeInterval = 10

    /// 低音量と見なす audioLevel 閾値。既存の RecordView.lowAudioWarning と揃える。
    private let lowAudioThreshold: Float = 0.08

    /// 低音量が継続したと見なすまでの秒数。RecordView の従来警告とも整合。
    private let lowAudioSustainedSeconds: TimeInterval = 5

    private let lightHaptic: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        return g
    }()

    /// 録音中のユーザーに向けて "いまどう受信されているか" を単一ピルで直接伝える。
    ///
    /// - connecting: ストリーム接続中（Deepgram WebSocket ハンドシェイク）
    /// - listening: 接続済だが初期 10s 以内で認識出力が無い通常状態（中性）
    /// - recognizing: 直近 5s 以内に interim / final セグメントを受け取っている = 正常
    /// - waitingForSpeech: 接続済・音量は足りているが一定秒数認識が来ていない
    /// - lowAudio: マイクに届く音量が閾値を下回る状態が 5s 以上続いている
    private enum Phase { case connecting, listening, recognizing, waitingForSpeech, lowAudio }
    private var phase: Phase {
        // isStartingLive は prepared session が無い状態での自前 connect 中に立つ。
        // これを connecting に含めないと "Listening…" → "Connecting" 表示切替が
        // 起きず、ユーザーから見ると「何も起きてない」に見える。
        let connecting = (coordinator.isPreparing || coordinator.isStartingLive)
            && !coordinator.isLiveActive
        if connecting { return .connecting }

        let now = Date()

        // 低音量判定を最優先。大講堂 / マイク遠距離の状況では Deepgram は無言になり、
        // "Waiting for speech" と出ても本当の原因は低音量なので、より具体的な
        // ガイダンスを優先する。
        if let since = lowAudioSince, now.timeIntervalSince(since) >= lowAudioSustainedSeconds {
            return .lowAudio
        }

        let elapsedSinceActivity = now.timeIntervalSince(lastActivityAt)
        let hasAnyContent = !coordinator.liveSegments.isEmpty || !coordinator.interimText.isEmpty

        if hasAnyContent {
            // 過去に認識実績あり: 直近 5s で "live" かどうかを切り替え。
            return elapsedSinceActivity < recognitionStaleSeconds ? .recognizing : .waitingForSpeech
        }
        // まだ何も受け取っていない: 初回10秒は中性グレーで "Listening…"。
        // 過ぎたら amber の "Waiting for speech" に escalate して何か問題が
        // 起きているかもと分かるようにする。
        return elapsedSinceActivity < waitingForSpeechSeconds ? .listening : .waitingForSpeech
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                statusPill
                Spacer()
                if phase == .recognizing {
                    HStack(spacing: 4) {
                        Image(systemName: "globe").font(.caption2)
                        Text("Auto").font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            content
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        )
        .onAppear {
            pulse = true
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                cursorOn.toggle()
            }
            lastHapticSegmentCount = coordinator.liveSegments.count
            // 初期時刻は view 表示時点。録音が既に走っていた場合も、直前の
            // activity を覚えていないので view 表示を起点にリセットしてしまう。
            // これで意図せず waitingForSpeech に落ちるのを防ぐ。
            lastActivityAt = Date()
            // 音量の現時点スナップショットで low の起点を仮置き。閾値より大きければ nil。
            lowAudioSince = recording.audioLevel < lowAudioThreshold ? Date() : nil
        }
        .onChange(of: coordinator.liveSegments.count) { _, newCount in
            if newCount > lastHapticSegmentCount, phase == .recognizing {
                lightHaptic.impactOccurred(intensity: 0.45)
                lightHaptic.prepare()
            }
            lastHapticSegmentCount = newCount
            lastActivityAt = Date()
        }
        .onChange(of: coordinator.interimText) { _, _ in
            // Deepgram interim は 100-200ms 周期で更新される。アクティビティの
            // 最も粒度細かい信号源なので、ここで lastActivityAt を更新しておけば
            // recognizing 判定が最新を反映する。
            lastActivityAt = Date()
        }
        .onChange(of: recording.audioLevel) { _, newLevel in
            // 録音中の audioLevel 更新は高頻度（~30Hz）。threshold を跨ぐ時だけ
            // lowAudioSince を更新する。RecordView 側の 5s ガードと整合させる。
            if newLevel < lowAudioThreshold {
                if lowAudioSince == nil { lowAudioSince = Date() }
            } else {
                lowAudioSince = nil
            }
        }
        // 1s ヒートビート。時間経過で phase が切り替わる (例: listening→waitingForSpeech)
        // 状況を再描画するため。onReceive 内では重い処理をせず、heartbeatTick を
        // インクリメントするだけ。phase は computed で毎回評価される。
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            heartbeatTick &+= 1
        }
    }

    // MARK: - Status pill

    private var statusPill: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(statusTint.opacity(0.25))
                    .frame(width: 14, height: 14)
                    .scaleEffect(pulse ? 1.3 : 0.7)
                    .opacity(pulse ? 0.0 : 1.0)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
                Circle()
                    .fill(statusTint)
                    .frame(width: 7, height: 7)
            }
            Text(statusLabel)
                .font(.caption.weight(.heavy))
                .foregroundStyle(statusTint)
                .tracking(1.4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(statusTint.opacity(0.12)))
    }

    private var statusLabel: String {
        switch phase {
        case .connecting:        return "CONNECTING"
        case .listening:         return "LISTENING"
        case .recognizing:       return "LIVE"
        case .waitingForSpeech:  return "WAITING FOR SPEECH"
        case .lowAudio:          return "MOVE CLOSER"
        }
    }
    private var statusTint: Color {
        switch phase {
        case .connecting:        return .blue
        case .listening:         return .secondary
        case .recognizing:       return .green
        case .waitingForSpeech:  return .orange
        case .lowAudio:          return Color(red: 1.0, green: 0.42, blue: 0.21)  // saturated orange-red
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .connecting:        connectingState
        case .listening:         listeningState
        case .recognizing:       lyricsScroll
        case .waitingForSpeech:
            // 過去に認識実績がある場合は lyrics を出したまま、empty 時のみ
            // 専用のガイダンスへ差し替え。履歴が突然消えるのを避ける。
            if coordinator.liveSegments.isEmpty && coordinator.interimText.isEmpty {
                waitingForSpeechState
            } else {
                lyricsScroll
            }
        case .lowAudio:
            // 低音量時も履歴は維持しつつ、追加ガイダンスを trailing 位置に出す
            // のが理想だが、初回録音 (履歴なし) の学会シナリオでは empty 下で
            // 明確なガイダンスを出す方が価値が高い。lyrics 維持ケースでは
            // 後続ガイダンスは pill 側の色で済ませる。
            if coordinator.liveSegments.isEmpty && coordinator.interimText.isEmpty {
                lowAudioState
            } else {
                lyricsScroll
            }
        }
    }

    // MARK: - Empty states

    private var connectingState: some View {
        VStack(spacing: 14) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.blue.opacity(0.35), lineWidth: 1.5)
                        .frame(width: CGFloat(26 + i * 20), height: CGFloat(26 + i * 20))
                        .scaleEffect(pulse ? 1.1 : 0.7)
                        .opacity(pulse ? 0 : 0.6)
                        .animation(
                            .easeOut(duration: 1.4)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.25),
                            value: pulse
                        )
                }
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 80, height: 80)

            VStack(spacing: 4) {
                Text("Preparing captions…")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Connecting to the transcription service")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(.vertical, 28)
    }

    private var listeningState: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(Color.secondary.opacity(0.55))
                        .frame(width: 4, height: barHeight(for: i))
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.12),
                            value: pulse
                        )
                }
            }
            .frame(height: 36)

            Text("Listening…")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(.vertical, 14)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [12, 24, 36, 24, 12]
        return pulse ? heights[index] : 8
    }

    /// waitingForSpeech: 接続 OK、音量 OK、でも 10s 以上認識出力が来ていない。
    /// 「沈黙なのか・話者がマイクから遠いのか」を次に判定するための中間状態。
    private var waitingForSpeechState: some View {
        VStack(spacing: 14) {
            Image(systemName: "ear")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.orange.opacity(0.9))

            VStack(spacing: 4) {
                Text("Waiting for speech…")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Connected, but no speech has been recognized yet.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
    }

    /// lowAudio: マイクに入る音量が 5s 以上 0.08 を下回っている。
    /// 大講堂 / 遠距離マイク問題の具体解 (「近づく・外部マイク」) を直接提示。
    private var lowAudioState: some View {
        VStack(spacing: 14) {
            Image(systemName: "mic.slash")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.21))

            VStack(spacing: 4) {
                Text("Audio is too quiet")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Move closer to the speaker, or plug in an external microphone.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
    }

    // MARK: - Lyrics-style scroll

    private var lyricsScroll: some View {
        let all = coordinator.liveSegments
        let hasInterim = !coordinator.interimText.isEmpty
        let total = all.count
        let lastFinalIndex = total - 1

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(Array(all.enumerated()), id: \.element.id) { pair in
                        let (idx, seg) = pair
                        let isActive = (idx == lastFinalIndex) && !hasInterim
                        lyricLine(
                            text: seg.text,
                            depth: total - 1 - idx,
                            isActive: isActive
                        )
                        .id(seg.id)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 12))
                                .animation(.easeOut(duration: 0.45)),
                            removal: .opacity.animation(.easeIn(duration: 0.2))
                        ))
                    }

                    if hasInterim {
                        InterimLyricLine(
                            text: coordinator.interimText,
                            cursorOn: cursorOn
                        )
                        .id("interim")
                    }

                    // 常に存在する「末尾センチネル」。単一 id で scrollTo する対象。
                    // segment/interim の id を切り替えるより、この固定 id に .bottom anchor で
                    // 吸着させる方が複数 onChange が並走しても結果がブレない。
                    Color.clear
                        .frame(height: 160)
                        .id("scroll-tail")
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 300-380pt の固定帯。maxHeight だけだと content に shrink して
            // アクティブ行が枠の最下段に貼り付いて見えるので minHeight も必須。
            .frame(minHeight: 300, maxHeight: 380)
            // 上端の硬い境界だけ柔らかくするための微かなマスク。
            // 以前は top 18% まで fade していて sparse な履歴が見えなくなる
            // バグがあったので 6% まで縮めた。
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.4), location: 0.0),
                        .init(color: .black, location: 0.06),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // 単一 key で scroll 判定を一本化。これまで count / interimText の
            // 2系統が並走して scrollTo を打ち合い、paragraph 拡張時（count 不変・text 伸長）
            // は誰も scroll せず、短い新 paragraph が来ると逆方向に跳ねる現象が出ていた。
            // - lastSegmentEnd: paragraph 拡張で増える → extend 時も trigger
            // - lastSegmentId: 新 paragraph 開始で変わる
            // - interimLen: interim 更新ごとに変わる
            .onChange(of: scrollFollowKey) { _, _ in
                // ease-out で短時間に統一。spring は response 小で overshoot→snap-back する
                // ことがあり、別 onChange と干渉して「戻る」感を生む元凶だった。
                withAnimation(.easeOut(duration: 0.28)) {
                    proxy.scrollTo("scroll-tail", anchor: .bottom)
                }
            }
        }
    }

    /// Scroll 追従を単一 onChange に集約するための合成 key。
    /// この値が変わった時だけ scrollTo が 1 回走る。
    private var scrollFollowKey: String {
        let lastId = coordinator.liveSegments.last?.id.uuidString ?? "-"
        // end が伸びる（paragraph 拡張）= trigger になる。四捨五入で微小変動を吸収。
        let lastEnd = Int((coordinator.liveSegments.last?.end ?? 0) * 10)
        let interimLen = coordinator.interimText.count
        return "\(lastId)|\(lastEnd)|\(interimLen)"
    }

    /// Apple Music 歌詞風の1行。depth が大きいほど小さく / 薄く。
    /// Font.system(size:) は SwiftUI の animatable property ではないので、
    /// `AnimatableFontSize` ViewModifier 経由でサイズを連続補間する。
    /// opacity / lineSpacing / weight は SwiftUI が Animatable にしてくれる。
    @ViewBuilder
    private func lyricLine(text: String, depth: Int, isActive: Bool) -> some View {
        let size: CGFloat = {
            if isActive { return 28 }
            switch depth {
            case 0, 1: return 19
            case 2:    return 16
            default:   return 14
            }
        }()
        let weight: Font.Weight = isActive ? .semibold : .regular
        let opacity: Double = {
            if isActive { return 1.0 }
            switch depth {
            case 0, 1: return 0.55
            case 2:    return 0.40
            default:   return 0.28
            }
        }()

        Text(text)
            .modifier(AnimatableFontSize(size: size, weight: weight))
            .foregroundStyle(Color.primary.opacity(opacity))
            .lineSpacing(size * 0.22)
            .fixedSize(horizontal: false, vertical: true)
            // spring で柔らかく補間。response 少し長め (0.55) で"溶けるように縮む"感。
            // damping 0.9 で overshoot 無し。value 毎に掛けることで個別 animate される。
            .animation(.spring(response: 0.55, dampingFraction: 0.9), value: size)
            .animation(.spring(response: 0.55, dampingFraction: 0.9), value: opacity)
            .animation(.easeInOut(duration: 0.35), value: isActive)
    }
}

// MARK: - AnimatableFontSize
//
// SwiftUI の `.font(.system(size:))` は animatable property として登録されていない
// ため、`.animation(...)` を付けても discrete (snap) で切り替わる。
// Animatable に conform した ViewModifier で `animatableData: Double` を
// 経由することで、フレーム毎に補間された `size` で `.font(...)` を再適用できる。
// weight は非 animatable なので、size の移行中は discrete に切り替わる（視覚的には
// size 遷移が支配的なので weight ジャンプはほぼ気づかない）。
struct AnimatableFontSize: ViewModifier, Animatable {
    var size: CGFloat
    var weight: Font.Weight

    var animatableData: CGFloat {
        get { size }
        set { size = newValue }
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: .rounded))
    }
}

// MARK: - Interim (smooth cross-fade update)

/// 喋られている途中のテキスト。Deepgram は interim を高頻度で投げてきて
/// (100-200ms 間隔)、その都度 ForEach で単語を keyed にすると
/// SwiftUI の再計算コストでチカチカして見える。
/// 単一 Text + `.contentTransition(.opacity)` で文字列全体を滑らかに
/// クロスフェードさせる方が Apple Music 歌詞の "テキストがにじみ出る"
/// 感覚に近い。
private struct InterimLyricLine: View {
    let text: String
    let cursorOn: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(text)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.92))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.22), value: text)

            Rectangle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 2.5, height: 28)
                .opacity(cursorOn ? 1.0 : 0.0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
