import Carbon

/// System-wide shortcut via Carbon's RegisterEventHotKey, which needs no Accessibility permission.
final class HotKey {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var isHandlerInstalled = false
    private static let signature = OSType(0x5547_4155) // "UGAU"

    private var reference: EventHotKeyRef?

    init(id: UInt32, keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        Self.installHandlerIfNeeded()
        Self.handlers[id] = handler
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: Self.signature, id: id),
                            GetApplicationEventTarget(), 0, &reference)
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
    }

    private static func installHandlerIfNeeded() {
        guard !isHandlerInstalled else { return }
        isHandlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            DispatchQueue.main.async { HotKey.handlers[hotKeyID.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
