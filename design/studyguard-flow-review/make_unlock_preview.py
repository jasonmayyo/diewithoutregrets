"""Build review-only Swift source from the current production presentation views.

The fixture transcript is not a provider response or an end-to-end grant test.
No production source is changed. Compile the generated source for iOS Simulator,
copy the built app's Assets.car into ChatPreview.app, then ad-hoc sign/install it.
"""
from pathlib import Path
import plistlib
import shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = Path('/private/tmp/studyguard-flow-review/native-preview')
OUT.mkdir(parents=True, exist_ok=True)

def read(path):
    return (ROOT / path).read_text()

model = read('diewithoutregrets/Shared/MonsterPersona.swift')
messages = read('diewithoutregrets/Features/TutorMonster/MonsterMessage.swift')
reactions = read('diewithoutregrets/Features/TutorMonster/MonsterReaction.swift')
reaction_views = read('diewithoutregrets/Features/TutorMonster/MonsterReactionView.swift')
script = read('diewithoutregrets/Features/TutorMonster/MonsterScript.swift')
source_model = 'struct FlashcardSource' + read('diewithoutregrets/Features/RegretGuard/Models/RegretGuardApps.swift').split('struct FlashcardSource', 1)[1].split('struct Regret:', 1)[0]
components = read('diewithoutregrets/Features/TutorMonster/MonsterChatComponents.swift')
study_model = read('diewithoutregrets/Features/TutorMonster/MonsterStudyRound.swift')
study_components = 'struct MonsterStudyButton:' + read('diewithoutregrets/Features/TutorMonster/MonsterStudySheet.swift').split('struct MonsterStudyButton:', 1)[1]
coins = read('diewithoutregrets/Features/RegretGuard/Views/QuizV2Coins.swift').split('// MARK: - Previews', 1)[0]
view = 'struct MonsterConversationView:' + read('diewithoutregrets/Features/TutorMonster/MonsterChatView.swift').split('struct MonsterConversationView:', 1)[1]
# Initialize the private composer state in this isolated copy only.
view = view.replace('@State private var draft = ""',
                    '@State private var draft = CaptureFixture.args.first(where: { $0.hasPrefix("--draft=") })?.replacingOccurrences(of: "--draft=", with: "") ?? ""')
view = view.replace('@State private var inquiryTarget: MonsterReplyTarget?',
                    '@State private var inquiryTarget: MonsterReplyTarget? = CaptureFixture.isInquiry ? CaptureFixture.inquiry : nil')
shield = read('StudyGuardShield/StudyGuardShieldExtension.swift')
shield_methods = shield.split('    fileprivate func studyGuardShield', 1)[1].split('#if DEBUG', 1)[0]
shield_preview = shield.split('struct StudyGuardShieldDesignPreview:', 1)[1].split('#Preview', 1)[0]
shield_source = ('import ManagedSettingsUI\nfinal class StudyGuardShieldExtension: ShieldConfigurationDataSource {\n'
                 '    fileprivate func studyGuardShield' + shield_methods +
                 '\nstruct StudyGuardShieldDesignPreview:' + shield_preview)

stubs = '''import SwiftUI
import UIKit
// Preview-only dependencies for the reused production flight components.
enum SGTheme {
    static let springFast = Animation.spring(response: 0.3, dampingFraction: 0.85)
    static let springPop = Animation.spring(response: 0.35, dampingFraction: 0.6)
}
enum QV2 {
    static let text = Color.primary
    static let orange = Color.orange
    static let tileBorder = Color.gray
    static func font(_ size: CGFloat, _ weight: Font.Weight) -> Font { .system(size: size, weight: weight) }
}
enum QuizHaptics { static func coinLand(progress: Double) {} }
struct Regret: Equatable {
    enum Mode { case choices, typed }
    struct Prompt { let text: String }
    let id: UUID
    let question: String
    let choices: [String]
    let answerMode: Mode
    var source: FlashcardSource? = nil
    var quizPrompt: Prompt { Prompt(text: question) }
}
enum SGContract {
    static let maxEarnedMinutes = 60
    enum MonsterMood { case chill, nudgy, annoyed, fedUp, feral }
    enum Keys { static let armedThresholdMinutes = "preview-unused"; static let selectedPersonaID = "sg_selectedPersonaID" }
    static var sharedDefaults: UserDefaults? { nil }
}
'''

fixture = r'''
enum CaptureFixture {
    static let args = ProcessInfo.processInfo.arguments
    static let state = args.first(where: { $0.hasPrefix("--state=") })?.replacingOccurrences(of: "--state=", with: "") ?? "correct"
    static let isInquiry = ["ask", "waiting", "reply", "offline"].contains(state)
    static let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 9, minute: 41))!
    static let card = Regret(id: UUID(), question: "What organelle is known as the powerhouse of the cell?", choices: ["Mitochondria", "Ribosome", "Nucleus", "Golgi apparatus"], answerMode: .choices)
    static let longCard = Regret(id: UUID(), question: "Which attachment style is associated with feeling comfortable with closeness and independence?", choices: ["The Secure Style", "The Anxious-Preoccupied Style", "The Dismissive-Avoidant Style", "The Fearful-Avoidant Style"], answerMode: .choices)
    static let next = Regret(id: UUID(), question: "What is the process plants use to convert light into energy?", choices: ["Respiration", "Photosynthesis", "Fermentation", "Osmosis"], answerMode: .choices)
    static let cell = Regret(id: UUID(), question: "What is the basic structural unit of all living organisms?", choices: ["The cell"], answerMode: .typed)
    static let last = Regret(id: UUID(), question: "Which molecule carries genetic information?", choices: ["RNA", "Protein", "DNA", "Lipid"], answerMode: .choices)
    static let cardMessage = m(.monster, .card(card))
    static let inquiry = MonsterReplyTarget(messageID: cardMessage.id, card: card)
    static let why = "Mitochondria generate most of the cell's ATP, its chemical energy currency."
    static func m(_ sender: MonsterMessage.Sender, _ kind: MonsterMessage.Kind) -> MonsterMessage {
        .init(sender: sender, kind: kind, createdAt: date)
    }
    static var rows: [MonsterMessage] {
        switch state {
        case "introduction":
            return []
        case "conversation":
            return [.monster("hiii 💅 quick one before you scroll."),
                    .monster("3 cards on this, then go off."), cardMessage]
        case "opening-source", "opening-single":
            let index = Int(args.first(where: { $0.hasPrefix("--opening-index=") })?.replacingOccurrences(of: "--opening-index=", with: "") ?? "0") ?? 0
            let vars = MonsterScriptVars(exam: "Biology", examDays: 2, topic: "Cell biology", questions: 3)
            let sources: [MonsterStudySource] = state == "opening-single"
                ? [.init(kind: .pdf, title: "Cell Biology — Chapter 4.pdf")]
                : [.init(kind: .pdf, title: "Cell Biology — Chapter 4.pdf"), .init(kind: .notes, title: "Pasted notes")]
            return [.monster(MonsterScript.openingGreeting(persona: .diva, mood: .chill, vars: vars, seed: index)),
                    .monster(MonsterScript.openingPrompt(persona: .diva, vars: vars, seed: index), sources: sources), cardMessage]
        case "reactions":
            return [.monster("wait you actually ate that 💅", reaction: .delightedLaugh), cardMessage]
        case "snack-break":
            return [m(.monster, .grant(minutes: 3)),
                    .monster("you earned your break. go enjoy it 💅", reaction: .snackBreak)]
        case "reaction-still":
            return [.monster("that's my clever one 💅", reaction: .rainbowRide), cardMessage]
        case "reaction-library":
            return MonsterReaction.allCases.map { .monster($0.rawValue, reaction: $0) }
        case "typed":
            return [.monster("One quick question."), m(.monster, .card(cell))]
        case "between":
            return [cardMessage, .user("Mitochondria"),
                    m(.monster, .reveal(correct: true, answer: "Mitochondria", why: nil))]
        case "choices-long":
            return [m(.monster, .text("One more, love. Take your time.")), m(.monster, .card(longCard))]
        case "correct":
            return [m(.monster, .card(cell)), m(.user, .text("The cell")),
                    m(.monster, .reveal(correct: true, answer: "The cell", why: nil)),
                    m(.monster, .text("That's my clever one.")), cardMessage]
        case "wrong":
            return [cardMessage, m(.user, .text("Ribosome")),
                    m(.monster, .reveal(correct: false, answer: "Mitochondria", why: why)),
                    m(.monster, .text("Close, pet. Let's try that again.")), m(.monster, .card(next))]
        case "ask":
            return [cardMessage]
        case "waiting":
            return [cardMessage, m(.user, .text("Why mitochondria and not ribosomes?"))]
        case "reply":
            return [cardMessage, m(.user, .text("Why mitochondria and not ribosomes?")),
                    m(.monster, .text("Think of mitochondria as the cell's energy suppliers, love. They make most of its ATP through cellular respiration. Ribosomes build proteins instead.\n\nSo for this card: energy production means mitochondria; protein production means ribosomes."))]
        case "resume":
            return [m(.monster, .text("Energy production means mitochondria; protein production means ribosomes.")),
                    m(.user, .text("Mitochondria")), m(.monster, .reveal(correct: true, answer: "Mitochondria", why: nil)),
                    m(.monster, .text("Lovely. Knew you had it.")), m(.monster, .card(next))]
        case "reward", "reward-first", "reward-second":
            return [cardMessage, m(.user, .text("Mitochondria")),
                    m(.monster, .reveal(correct: true, answer: "Mitochondria", why: nil)),
                    m(.monster, .text("Lovely. Knew you had it.")), m(.monster, .card(next)),
                    m(.user, .text("Photosynthesis")),
                    m(.monster, .reveal(correct: true, answer: "Photosynthesis", why: nil)),
                    m(.monster, .text("That's my clever one.")), m(.monster, .grant(minutes: 3)),
                    m(.monster, .text("Lovely work. Enjoy your 3 minutes.")),
                    m(.system, .text("Recap: 2/2 locked in."))]
        case "complete":
            return [m(.monster, .card(last)), m(.user, .text("DNA")),
                    m(.monster, .text("There it is.")), m(.monster, .grant(minutes: 2)),
                    m(.monster, .text("Lovely work. Enjoy your 2 minutes.")),
                    m(.system, .text("Recap: 4/4 locked in.")), m(.monster, .text("I'll be right here when you're back."))]
        case "offline":
            return [cardMessage, m(.user, .text("Why is that correct?")),
                    m(.monster, .text("I can't reach the live tutor right now. Here's the saved explanation for this card:\n\n" + why))]
        default:
            return [cardMessage]
        }
    }
}
@main struct ChatPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            Group {
                if CaptureFixture.state == "shield" {
                    StudyGuardShieldDesignPreview(persona: .willow)
                } else {
                    ReviewRoot()
                }
            }.preferredColorScheme(.light)
        }
    }
}
struct ReviewRoot: View {
    let state = CaptureFixture.state
    let rows = CaptureFixture.rows
    @State private var rewardStage = 0
    @State private var liveRows: [MonsterMessage] = []
    @StateObject private var presenter = MonsterTranscriptPresenter(
        onMonsterMessage: { _ in MonsterChatHaptics.messageReceived() }
    )
    private var live: Bool { state == "conversation" }
    private var responding: Bool { live ? presenter.revealed < liveRows.count : ["introduction", "between", "waiting"].contains(state) }
    private var complete: Bool { ["complete", "snack-break"].contains(state) || (state == "reward" && rewardStage == 4) }
    private var visibleRows: [MonsterMessage] {
        if live { return Array(liveRows.prefix(presenter.revealed)) }
        if state == "reward-first" { return Array(rows.prefix(5)) }
        if state == "reward-second" { return Array(rows.prefix(8)) }
        return state == "reward" ? Array(rows.prefix([1, 4, 5, 8, rows.count][rewardStage])) : rows
    }
    var body: some View {
        MonsterConversationView(
            persona: .diva, messages: visibleRows,
            isTyping: live ? presenter.isTyping : ["introduction", "between", "waiting"].contains(state),
            replyTarget: complete || responding || state == "reward" ? nil : MonsterReplyTarget.current(
                messages: visibleRows, revealed: visibleRows.count,
                activeCard: live ? visibleRows.last(where: { $0.card != nil })?.card : state == "typed" ? CaptureFixture.cell : state == "choices-long" ? CaptureFixture.longCard : ["wrong", "resume"].contains(state) ? CaptureFixture.next : CaptureFixture.card,
                isThinking: false),
            isFinished: complete, grantedMinutes: state == "complete" ? 2 : rewardStage >= 3 ? 3 : 0,
            totalQuestions: state.hasPrefix("reward") ? 2 : 3,
            secondsPerCorrectAnswer: 75,
            allowanceSeconds: state == "complete" ? 120 : rewardStage >= 3 ? 180 : state == "balance" ? 300 : 0,
            onClose: {}, onChoice: { _, index in
                guard live else { return }
                let card = visibleRows.last(where: { $0.card != nil })!.card!
                submitPreviewAnswer(card.choices[index])
            }, onTyped: { _, text in submitPreviewAnswer(text) }, isResponding: responding)
            .environment(\.dynamicTypeSize, CaptureFixture.args.contains("--large-text") ? .accessibility3 : .large)
            .task {
                if live {
                    liveRows = rows
                    presenter.update(messages: liveRows, isVisible: true)
                    return
                }
                guard state == "reward" else { return }
                for stage in 1...4 {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled else { return }
                    rewardStage = stage
                }
            }
    }

    private func submitPreviewAnswer(_ text: String) {
        guard live else { return }
        liveRows += [.user(text),
                     .init(sender: .monster, kind: .reveal(correct: true, answer: text, why: nil)),
                     .monster("Exactly! Let's do another.", reaction: .delightedLaugh),
                     .init(sender: .monster, kind: .card(CaptureFixture.next))]
        presenter.update(messages: liveRows, isVisible: true)
    }
}
'''
source = stubs + source_model + model + study_model + script + reactions + messages + coins + components + reaction_views + study_components + view + shield_source + fixture
# This system environment value is read-only. In this isolated fixture, force
# the same production branch for a repeatable reduced-motion capture.
source = source.replace('@Environment(\\.accessibilityReduceMotion) private var reduceMotion',
                        'private let reduceMotion = ProcessInfo.processInfo.arguments.contains("--reduce-motion")')
(OUT / 'IOSPreview.swift').write_text(source)
app = OUT / 'ChatPreview.app'
app.mkdir(exist_ok=True)
shutil.copytree(ROOT / 'diewithoutregrets/Resources/MonsterReactions', app / 'MonsterReactions', dirs_exist_ok=True)
info = {'CFBundleExecutable': 'ChatPreview', 'CFBundleIdentifier': 'com.studyguard.chatpreview',
        'CFBundleName': 'Chat Preview', 'CFBundlePackageType': 'APPL',
        'CFBundleShortVersionString': '1.0', 'CFBundleVersion': '1',
        'MinimumOSVersion': '17.4', 'LSRequiresIPhoneOS': True, 'UIDeviceFamily': [1],
        'UILaunchScreen': {}, 'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'],
        'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False}}
(app / 'Info.plist').write_bytes(plistlib.dumps(info))
for name in ['willow', 'zaza', 'sarge', 'gnash']:
    asset = f'monster-{name}-atlas.imageset'
    shutil.copytree(ROOT / 'diewithoutregrets/Assets.xcassets' / asset, app / asset, dirs_exist_ok=True)
print(OUT / 'IOSPreview.swift')
