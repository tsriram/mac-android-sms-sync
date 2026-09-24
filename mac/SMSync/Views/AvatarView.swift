import SwiftUI

struct AvatarView: View {
    let name: String
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor)
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }

    private var initials: String {
        let clean = name
            .replacingOccurrences(of: "+", with: "")
            .components(separatedBy: CharacterSet.letters.inverted)
            .joined()
        guard !clean.isEmpty else { return "#" }

        let words = clean.split(separator: " ").filter { !$0.isEmpty }
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(clean.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        let palette: [Color] = [
            .red, .orange, .green, .teal,
            .indigo, .purple, .pink, .brown
        ]
        let hash = abs(name.utf8.reduce(0) { $0 &+ Int($1) })
        return palette[hash % palette.count]
    }
}