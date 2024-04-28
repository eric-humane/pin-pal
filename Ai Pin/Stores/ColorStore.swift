import SwiftUI

@Observable final class ColorStore: Sendable {
    var accentColor: Color = .blue;
    
    init() {
        if let _ = UserDefaults.standard.object(forKey: "accentColor") {
            self.accentColor = loadColor()
        }
    }
    
    func setColor(color: Color) {
        let cgColor = UIColor(color).cgColor
        UserDefaults.standard.set(cgColor.components, forKey: "accentColor")
        accentColor = color
    }
    
    func loadColor() -> Color {
        guard let colorArray = UserDefaults.standard.object(forKey: "accentColor") as? [CGFloat] else {
            return Color.blue
        }
        
        let finalColor = Color(.sRGB, red: colorArray[0], green: colorArray[1], blue: colorArray[2], opacity: colorArray[3]);
        
        return finalColor
    }
}
