// Entry point: picks the app struct by OS version — see BMO.swift.
if #available(macOS 15.0, *) {
    BMOApp.main()
} else {
    BMOAppMacOS14.main()
}
