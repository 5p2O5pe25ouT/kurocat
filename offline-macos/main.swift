import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let pet = Pet()
app.delegate = pet
app.run()
