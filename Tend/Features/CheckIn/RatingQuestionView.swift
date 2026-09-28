import SwiftUI

struct RatingQuestionView: View {
    let number: Int
    let question: String
    let key: String
    let lower: String
    let upper: String
    @Binding var selection: Int?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(String(format: "%02d", number)).font(.subheadline.monospacedDigit()).foregroundStyle(TendTheme.secondary).padding(.top, 5)
                Text(question).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    Button { selection = value } label: {
                        Text("\(value)").font(.title3.weight(selection == value ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(selection == value ? TendTheme.onForest : TendTheme.ink)
                            .background(selection == value ? TendTheme.forest : TendTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selection == value ? TendTheme.forest : TendTheme.line))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(question), \(value) of 5")
                    .accessibilityValue(selection == value ? "Selected" : "Not selected")
                    .accessibilityAddTraits(selection == value ? .isSelected : [])
                    .accessibilityIdentifier("ema.\(key).\(value)")
                }
            }
            HStack(alignment: .top) {
                Text(lower)
                Spacer(minLength: 16)
                Text(upper).multilineTextAlignment(.trailing)
            }.font(.subheadline).foregroundStyle(TendTheme.secondary)
        }.padding(.vertical, 4)
    }
}

struct TimeQuestionView: View {
    @Binding var selection: AvailableTime?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("06").font(.subheadline.monospacedDigit()).foregroundStyle(TendTheme.secondary).padding(.top, 5)
                Text("How much time do you have available right now?")
                    .font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AvailableTime.allCases, id: \.self) { time in
                    Button { selection = time } label: {
                        HStack {
                            Text(time.label).font(.subheadline.weight(.medium))
                            Spacer(minLength: 4)
                            if selection == time { Image(systemName: "checkmark").font(.caption.weight(.semibold)) }
                        }
                        .padding(.horizontal, 14).frame(minHeight: 56)
                        .foregroundStyle(selection == time ? TendTheme.onForest : TendTheme.ink)
                        .background(selection == time ? TendTheme.forest : TendTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selection == time ? TendTheme.forest : TendTheme.line))
                    }.buttonStyle(.plain).accessibilityIdentifier("ema.time.\(time.rawValue)")
                        .accessibilityAddTraits(selection == time ? .isSelected : [])
                }
            }
        }.padding(.vertical, 4)
    }
}
