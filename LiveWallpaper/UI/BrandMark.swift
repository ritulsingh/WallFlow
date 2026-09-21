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
                    .strokeBorder(.white.opacity(size > 40 ? 0.14 : 0), lineWidth: 0.5)
            )
            .shadow(color: glow ? Color.cyan.opacity(0.22) : .clear, radius: 28, y: 10)

        let name = Text("WallFlow")
            .font(size > 40 ? .system(size: 32, weight: .semibold) : .headline)
            .foregroundStyle(nameColor)

        if showName, axis == .vertical {
            VStack(spacing: 14) {
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
