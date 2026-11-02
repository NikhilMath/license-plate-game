import SwiftUI

struct LicensePlateCard: View {
    let state: USState
    let spotted: Bool
    /// Every player who has spotted this plate, shown as colored dots.
    let spotters: [Player]

    var body: some View {
        VStack(spacing: 2) {
            Text(state.plateTitle.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(state.region.color)

            Text(state.code)
                .font(.system(size: 34, weight: .black, design: .monospaced))
                .foregroundStyle(spotted ? state.region.color : .secondary)
                .padding(.top, 2)

            Text(state.nickname)
                .font(.system(size: 9, weight: .semibold))
                .italic()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)

            HStack(spacing: 3) {
                ForEach(spotters) { player in
                    Circle().fill(player.color).frame(width: 7, height: 7)
                }
            }
            .frame(height: 9)
            .padding(.bottom, 4)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(spotted ? state.region.color : Color.secondary.opacity(0.35),
                              style: StrokeStyle(lineWidth: spotted ? 3 : 1.5, dash: spotted ? [] : [5, 3]))
        )
        .overlay(alignment: .topTrailing) {
            if spotted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
                    .background(Circle().fill(.white).padding(2))
                    .offset(x: 6, y: -8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .opacity(spotted ? 1 : 0.75)
        .shadow(color: .black.opacity(spotted ? 0.15 : 0), radius: 4, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(state.name), \(spotted ? "spotted" : "not spotted")")
    }
}
