import AppKit

/// Full-screen "cleaning mode" curtain shown on every display while locked.
final class LockOverlay {
    private var windows: [NSWindow] = []
    private var countdownLabels: [NSTextField] = []
    var onUnlockButton: (() -> Void)?

    func show(pointerLocked: Bool, secondsLeft: Int) {
        hide()
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.backgroundColor = NSColor.black.withAlphaComponent(0.92)
            window.isOpaque = false
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.contentView = makeContent(pointerLocked: pointerLocked, isMain: screen == NSScreen.main)
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
        update(secondsLeft: secondsLeft)
    }

    func update(secondsLeft: Int) {
        let text = String(format: "Se desbloquea solo en %d:%02d", secondsLeft / 60, secondsLeft % 60)
        countdownLabels.forEach { $0.stringValue = text }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        countdownLabels.removeAll()
    }

    private func makeContent(pointerLocked: Bool, isMain: Bool) -> NSView {
        let root = NSView()

        let icon = NSImageView()
        let config = NSImage.SymbolConfiguration(pointSize: 120, weight: .light)
            .applying(.init(paletteColors: [.white, .systemTeal]))
        icon.image = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
            ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)?.withSymbolConfiguration(config)

        let title = label(pointerLocked ? "Teclado y trackpad bloqueados" : "Teclado bloqueado",
                          size: 40, weight: .semibold, color: .white)
        let subtitle = label("Ya puedes limpiar tranquilo ✨", size: 22, weight: .regular,
                             color: NSColor.white.withAlphaComponent(0.8))

        let chord = label("Control + U  para desbloquear", size: 26, weight: .medium, color: .systemTeal)
        let countdown = label("", size: 18, weight: .regular, color: NSColor.white.withAlphaComponent(0.6))
        countdown.font = .monospacedDigitSystemFont(ofSize: 18, weight: .regular)
        countdownLabels.append(countdown)

        let note = label("El botón de encendido / Touch ID no se bloquea.", size: 13, weight: .regular,
                         color: NSColor.white.withAlphaComponent(0.4))

        var views: [NSView] = [icon, title, subtitle, spacer(18), chord, countdown]
        if !pointerLocked {
            let button = NSButton(title: "Desbloquear", target: self, action: #selector(unlockClicked))
            button.bezelStyle = .rounded
            button.controlSize = .large
            views += [spacer(8), button]
        }
        views += [spacer(30), note]

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
        ])
        return root
    }

    @objc private func unlockClicked() { onUnlockButton?() }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.alignment = .center
        return l
    }

    private func spacer(_ h: CGFloat) -> NSView {
        let v = NSView()
        v.heightAnchor.constraint(equalToConstant: h).isActive = true
        return v
    }
}
