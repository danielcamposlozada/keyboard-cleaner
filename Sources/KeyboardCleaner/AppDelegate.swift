import AppKit
import KeylockCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let locker = InputLocker()
    private let overlay = LockOverlay()
    private var countdown: Timer?
    private var secondsLeft = 0

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.toolTip = "Keyboard Cleaner"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshIcon()

        locker.onUnlockChord = { [weak self] in self?.unlock() }
        overlay.onUnlockButton = { [weak self] in self?.unlock() }

        if !InputLocker.hasAccessibilityPermission() {
            DispatchQueue.main.async { self.showPermissionAlert() }
        }
    }

    /// Clicking the app again (Dock, Finder, Spotlight) opens the menu.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem.button?.performClick(nil)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        locker.unlock()
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if locker.isLocked {
            menu.addItem(item("Desbloquear", #selector(unlockAction)))
            return
        }

        let hasPermission = InputLocker.hasAccessibilityPermission()

        let kb = item("Limpiar teclado", #selector(lockKeyboard))
        kb.image = symbol("keyboard")
        let all = item("Limpiar teclado y trackpad", #selector(lockAll))
        all.image = symbol("hand.raised.slash")
        [kb, all].forEach { $0.isEnabled = hasPermission; menu.addItem($0) }

        menu.addItem(.separator())

        let timerMenu = NSMenu()
        for s in Settings.autoUnlockChoices {
            let i = item(Settings.label(forSeconds: s), #selector(setTimer(_:)))
            i.tag = s
            i.state = s == Settings.autoUnlockSeconds ? .on : .off
            timerMenu.addItem(i)
        }
        let timerItem = NSMenuItem(title: "Desbloqueo automático: \(Settings.label(forSeconds: Settings.autoUnlockSeconds))",
                                   action: nil, keyEquivalent: "")
        timerItem.submenu = timerMenu
        menu.addItem(timerItem)

        let sys = item("Bloquear brillo, volumen y multimedia", #selector(toggleSystemKeys))
        sys.state = Settings.blockSystemKeys ? .on : .off
        menu.addItem(sys)

        let sounds = item("Sonidos", #selector(toggleSounds))
        sounds.state = Settings.playSounds ? .on : .off
        menu.addItem(sounds)

        let login = item("Abrir al iniciar sesión", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        if !hasPermission {
            let p = item("⚠️ Dar permiso de Accesibilidad…", #selector(openPermission))
            menu.addItem(p)
        }
        let hint = NSMenuItem(title: "Para desbloquear: Control + U", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        menu.addItem(.separator())
        menu.addItem(item("Acerca de Keyboard Cleaner", #selector(about)))
        menu.addItem(item("Salir", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    private func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    private func refreshIcon() {
        let name = locker.isLocked ? "lock.fill" : "keyboard"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Keyboard Cleaner")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    // MARK: Actions

    @objc private func lockKeyboard() { lock(pointer: false) }
    @objc private func lockAll() { lock(pointer: true) }
    @objc private func unlockAction() { unlock() }

    @objc private func setTimer(_ sender: NSMenuItem) { Settings.autoUnlockSeconds = sender.tag }
    @objc private func toggleSystemKeys() { Settings.blockSystemKeys.toggle() }
    @objc private func toggleSounds() { Settings.playSounds.toggle() }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            alert("No se pudo cambiar el inicio automático", error.localizedDescription)
        }
    }

    @objc private func openPermission() {
        _ = InputLocker.hasAccessibilityPermission(prompt: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "Bloquea el teclado (y el trackpad si quieres) para limpiarlo.\n"
                + "Basado en keylock de kfv — github.com/kfv/keylock (MIT).",
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Lock flow

    private func lock(pointer: Bool) {
        do {
            try locker.lock(options: LockOptions(blockPointer: pointer,
                                                 blockSystemKeys: Settings.blockSystemKeys))
        } catch InputLockerError.accessibilityPermissionMissing {
            showPermissionAlert()
            return
        } catch {
            alert("No se pudo bloquear", "\(error.localizedDescription)\n\nRevisa el permiso de Accesibilidad.")
            return
        }

        secondsLeft = Settings.autoUnlockSeconds
        NSApp.activate(ignoringOtherApps: true)
        overlay.show(pointerLocked: pointer, secondsLeft: secondsLeft)
        if !pointer { NSCursor.unhide() } else { NSCursor.hide() }
        play("Pop")
        refreshIcon()

        countdown = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.secondsLeft -= 1
            if self.secondsLeft <= 0 { self.unlock() } else { self.overlay.update(secondsLeft: self.secondsLeft) }
        }
        RunLoop.main.add(countdown!, forMode: .common)
    }

    private func unlock() {
        guard locker.isLocked else { return }
        countdown?.invalidate()
        countdown = nil
        locker.unlock()
        overlay.hide()
        NSCursor.unhide()
        play("Glass")
        refreshIcon()
    }

    private func play(_ name: String) {
        guard Settings.playSounds else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    // MARK: Alerts

    private func showPermissionAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Keyboard Cleaner necesita permiso de Accesibilidad"
        a.informativeText = "Sin este permiso no puede bloquear el teclado.\n\n"
            + "Ajustes del Sistema → Privacidad y seguridad → Accesibilidad → activa “Keyboard Cleaner”."
        a.addButton(withTitle: "Abrir Ajustes")
        a.addButton(withTitle: "Más tarde")
        if a.runModal() == .alertFirstButtonReturn { openPermission() }
    }

    private func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }
}
