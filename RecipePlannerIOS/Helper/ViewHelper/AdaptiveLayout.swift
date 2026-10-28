import SwiftUI

/// Soft decorative glows anchored to the available container edges instead of
/// fixed points that only line up on one phone-sized screen.
struct WickedAmbientGlowLayer: View {
    var pinkOpacity: Double = 0.3
    var greenOpacity: Double = 0.3
    var blueOpacity: Double = 0

    var pinkDiameter: CGFloat = 300
    var greenDiameter: CGFloat = 250
    var blueDiameter: CGFloat = 280

    var body: some View {
        Color.clear
            .overlay(alignment: .topTrailing) {
                if pinkOpacity > 0 {
                    Ellipse()
                        .fill(Color.glindaPink.opacity(pinkOpacity))
                        .frame(width: pinkDiameter, height: pinkDiameter)
                        .blur(radius: pinkDiameter * 0.33)
                        .offset(x: pinkDiameter * 0.35, y: -pinkDiameter * 0.33)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if greenOpacity > 0 {
                    Ellipse()
                        .fill(Color.wickedGreen.opacity(greenOpacity))
                        .frame(width: greenDiameter, height: greenDiameter)
                        .blur(radius: greenDiameter * 0.38)
                        .offset(x: -greenDiameter * 0.25, y: greenDiameter * 0.28)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if blueOpacity > 0 {
                    Ellipse()
                        .fill(Color.wickedBlue.opacity(blueOpacity))
                        .frame(width: blueDiameter, height: blueDiameter)
                        .blur(radius: blueDiameter * 0.4)
                        .offset(x: blueDiameter * 0.4, y: blueDiameter * 0.06)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Centers content on wide windows while leaving narrow-device sizing unchanged.
    func wickedReadableWidth(_ maximumWidth: CGFloat = 900) -> some View {
        frame(maxWidth: maximumWidth)
            .frame(maxWidth: .infinity)
    }
}
