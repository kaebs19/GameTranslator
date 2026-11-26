import SwiftUI

/// Same content as `Docs/privacy-policy.html`; keep both in step.
struct PrivacyPolicyView: View {
    private struct Topic {
        let title: LocalizedStringResource
        let text: LocalizedStringResource
    }

    private let topics: [Topic] = [
        Topic(title: .privacySummaryTitle, text: .privacySummaryText),
        Topic(title: .privacyImagesTitle, text: .privacyImagesText),
        Topic(title: .privacyCameraTitle, text: .privacyCameraText),
        Topic(title: .privacyBroadcastTitle, text: .privacyBroadcastText),
        Topic(title: .privacyTextTitle, text: .privacyTextText),
        Topic(title: .privacyServerTitle, text: .privacyServerText),
        Topic(title: .privacyCloudTitle, text: .privacyCloudText),
        Topic(title: .privacyTvTitle, text: .privacyTvText),
        Topic(title: .privacyAppleTitle, text: .privacyAppleText),
        Topic(title: .privacyContactTitle, text: .privacyContactText),
        Topic(title: .privacyControlTitle, text: .privacyControlText)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                ForEach(topics.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text(topics[index].title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Text(topics[index].text)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(Text(.privacyTitle))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground.ignoresSafeArea())
    }
}
