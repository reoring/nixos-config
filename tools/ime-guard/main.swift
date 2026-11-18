import AppKit
import Carbon
import OSLog

// Both SKK engines expose each input mode as its own TIS input source:
// AquaSKK `...aquaskk.Hiragana`, macSKK `...macSKK.hiragana`. The guard treats
// any source under these prefixes as "a SKK mode is in use".
let skkPrefixes = [
    "jp.sourceforge.inputmethod.aquaskk.",
    "net.mtgto.inputmethod.macSKK.",
]
// Used only before anything has been remembered: hiragana on whichever engine
// is actually enabled, macSKK first.
let defaultSources = [
    "net.mtgto.inputmethod.macSKK.hiragana",
    "jp.sourceforge.inputmethod.aquaskk.Hiragana",
]
let abcID = "com.apple.keylayout.ABC"
let preferences = UserDefaults(suiteName: "local.reoring.ime-guard")!
let logger = Logger(subsystem: "local.reoring.ime-guard", category: "input-source")

func isSkk(_ id: String) -> Bool {
    skkPrefixes.contains { id.hasPrefix($0) }
}

func stringProperty(_ source: TISInputSource, _ key: CFString) -> String {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return "" }
    return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
}
func flag(_ source: TISInputSource, _ key: CFString) -> Bool {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return false }
    return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
}
func currentID() -> String {
    stringProperty(TISCopyCurrentKeyboardInputSource().takeRetainedValue(), kTISPropertyInputSourceID)
}
func availableSources() -> [TISInputSource] {
    TISCreateInputSourceList(nil, false).takeRetainedValue() as! [TISInputSource]
}
func source(_ id: String) -> TISInputSource? {
    availableSources().first {
        stringProperty($0, kTISPropertyInputSourceID) == id &&
        flag($0, kTISPropertyInputSourceIsEnabled) && flag($0, kTISPropertyInputSourceIsSelectCapable)
    }
}
func sessionAvailable() -> Bool {
    guard let info = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
    return info[kCGSessionOnConsoleKey as String] as? Bool == true &&
        info["CGSSessionScreenIsLocked"] as? Bool != true
}
func status() {
    let result: [String: Any] = [
        "selected": currentID(), "secureInput": IsSecureEventInputEnabled(),
        "sessionAvailable": sessionAvailable(),
        "lastSkk": preferences.string(forKey: "lastSource") ?? "",
        "sources": availableSources().filter { flag($0, kTISPropertyInputSourceIsSelectCapable) }
            .map { stringProperty($0, kTISPropertyInputSourceID) }
    ]
    let data = try! JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: data, as: UTF8.self))
}

final class Guard {
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var pending: DispatchWorkItem?
    private var timer: Timer?
    private var deferred = false
    private var attempted = false
    private var recentAttempts: [TimeInterval] = []
    private var circuitOpen = false
    private var lastObserved = ""
    private var lastPID: pid_t = 0

    func start() {
        observe(DistributedNotificationCenter.default(),
                Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String))
        observe(DistributedNotificationCenter.default(),
                Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String))
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didActivateApplicationNotification)
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.sessionDidBecomeActiveNotification)
        observe(DistributedNotificationCenter.default(), Notification.Name("com.apple.screenIsUnlocked"))
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.deferred else { return }
            self.schedule("secure/session recheck")
        }
        logger.info("guard started")
        schedule("startup")
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
            self?.schedule(note.name.rawValue)
        }
        observers.append((center, token))
    }

    private func schedule(_ reason: String) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.check(reason) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func check(_ reason: String) {
        let selected = currentID()
        let app = NSWorkspace.shared.frontmostApplication
        let pid = app?.processIdentifier ?? 0
        let appID = app?.bundleIdentifier ?? "unknown"
        if pid != lastPID {
            lastPID = pid
            attempted = false
            circuitOpen = false
        }
        if selected != lastObserved {
            logger.info("source=\(selected, privacy: .public) app=\(appID, privacy: .public) event=\(reason, privacy: .public)")
            lastObserved = selected
        }
        if isSkk(selected) {
            if preferences.string(forKey: "lastSource") != selected {
                preferences.set(selected, forKey: "lastSource")
            }
            attempted = false
            deferred = false
            return
        }
        guard selected == abcID else { deferred = false; return }
        guard sessionAvailable(), !IsSecureEventInputEnabled() else {
            if !deferred { logger.info("ABC restore deferred: secure input or inactive/locked session") }
            deferred = true
            return
        }
        deferred = false
        guard !attempted, !circuitOpen else { return }
        let now = ProcessInfo.processInfo.systemUptime
        recentAttempts.removeAll { now - $0 > 30 }
        guard recentAttempts.count < 3 else {
            circuitOpen = true
            logger.error("restore paused after 3 attempts in 30s; switch apps to re-arm")
            return
        }
        // Do not silently substitute a different mode if the remembered one was
        // disabled; a default applies only while nothing has been remembered.
        let remembered = preferences.string(forKey: "lastSource")
            .flatMap { isSkk($0) ? $0 : nil }
        let preferred = remembered ?? defaultSources.first { source($0) != nil }
        guard let preferred, let target = source(preferred) else {
            attempted = true
            logger.error("no SKK mode available to restore; select one manually to resume")
            return
        }
        // Recheck immediately before the mutation; notifications may be delayed.
        guard currentID() == abcID, sessionAvailable(), !IsSecureEventInputEnabled() else {
            deferred = true
            return
        }
        attempted = true
        recentAttempts.append(now)
        let result = TISSelectInputSource(target)
        logger.info("restore ABC -> \(preferred, privacy: .public) app=\(appID, privacy: .public) status=\(result)")
        // A failed selection is not retried until app activation or a SKK selection.
    }
}

let args = Array(CommandLine.arguments.dropFirst())
if args == ["--status"] {
    status()
} else if args.count == 2 && args[0] == "--select" {
    guard sessionAvailable(), !IsSecureEventInputEnabled() else {
        fputs("Selection refused during secure input or inactive session\n", stderr)
        exit(1)
    }
    guard let target = source(args[1]) else { fputs("Input source unavailable\n", stderr); exit(1) }
    let result = TISSelectInputSource(target)
    if result != noErr { fputs("TISSelectInputSource failed: \(result)\n", stderr); exit(1) }
} else if args.isEmpty {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let inputGuard = Guard()
    inputGuard.start()
    withExtendedLifetime(inputGuard) { app.run() }
} else {
    fputs("Usage: ime-guard [--status | --select INPUT_SOURCE_ID]\n", stderr)
    exit(2)
}
