import Foundation

struct OnboardingPage: Identifiable {
    let id: String
    let icon: String
    let title: LocalizedStringResource
    let points: [LocalizedStringResource]

    static let all = [
        OnboardingPage(
            id: "instant", icon: "text.viewfinder", title: .onboardingInstantTitle,
            points: [.onboardingInstantPoint1, .onboardingInstantPoint2, .onboardingInstantPoint3]
        ),
        OnboardingPage(
            id: "camera", icon: "camera.viewfinder", title: .onboardingCameraTitle,
            points: [.onboardingCameraPoint1, .onboardingCameraPoint2, .onboardingCameraPoint3]
        ),
        OnboardingPage(
            id: "live", icon: "dot.radiowaves.left.and.right", title: .onboardingLiveTitle,
            points: [.onboardingLivePoint1, .onboardingLivePoint2, .onboardingLivePoint3]
        ),
        OnboardingPage(
            id: "privacy", icon: "lock.shield", title: .onboardingPrivacyTitle,
            points: [.onboardingPrivacyPoint1, .onboardingPrivacyPoint2, .onboardingPrivacyPoint3]
        )
    ]
}
