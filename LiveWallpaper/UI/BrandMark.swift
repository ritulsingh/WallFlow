import SwiftUI

struct BrandMark: View {
    var size: CGFloat = 22
    var showName = false
    var axis: Axis = .horizontal
    var nameColor: Color = .primary
    var glow = false

    var body: some View {
        let mark = Image("Logo")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(.white.opacity(size > 40 ? 0.12 : 0), lineWidth: 0.5)
            )
            .shadow(color: glow ? Color.accentColor.opacity(0.28) : .clear, radius: 24, y: 8)

        let name = Text("WallFlow")
            .font(size > 40
                  ? .system(size: 30, weight: .semibold, design: .rounded)
                  : .system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(nameColor)
            .tracking(-0.2)

        if showName, axis == .vertical {
            VStack(spacing: 16) {
                mark
                name
            }
        } else if showName {
            HStack(spacing: 8) {
                mark
                name
            }
        } else {
            mark
        }
    }
}
