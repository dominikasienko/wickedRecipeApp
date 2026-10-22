import SwiftUI

struct PrivacyPolicyNotice: View {
    var body: some View {
        VStack(spacing: 4) {
            Text(AppLocalization.key("By continuing, you confirm that you have read the Privacy Policy."))
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.72))

            Link(AppLocalization.key("Privacy Policy"), destination: LegalLinks.privacyPolicy)
            .font(.footnote.weight(.semibold))
            .tint(Color.wickedGreen)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
