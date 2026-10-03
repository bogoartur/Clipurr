import AppKit

/// Public synthetic content for repeatable screenshots and OCR verification.
enum DemoSamples {
    @MainActor
    static func notesImage() -> Data {
        let image = NSImage(size: NSSize(width: 720, height: 240))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 720, height: 240).fill()
        let style: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 38, weight: .semibold),
            .foregroundColor: NSColor.black
        ]
        ("Workshop notes\nReact PHP PostgreSQL" as NSString).draw(
            in: NSRect(x: 30, y: 35, width: 660, height: 175), withAttributes: style
        )
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        return bitmap.representation(using: .png, properties: [:])!
    }
}
