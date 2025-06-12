////
////  MeshGradient.swift
////  diewithoutregrets
////
////  Created by Mayo on 2024/05/20.
////
////  A clean, modern mesh gradient designed for the Study Guard app.
//
//import SwiftUI
//
//struct StudyGuardMeshGradient: View {
//    // Theme colors for Study Guard app
//    let primaryColor: Color
//    let secondaryColor: Color
//    let accentColor: Color
//    
//    // Animation properties
//    @State private var animationPhase: Double = 0
//    let animationSpeed: Double
//    let animated: Bool
//    
//    init(
//        primaryColor: Color = Color(red: 0.2, green: 0.4, blue: 0.8), // Study blue
//        secondaryColor: Color = Color(red: 0.1, green: 0.7, blue: 0.6), // Study teal
//        accentColor: Color = Color(red: 0.9, green: 0.4, blue: 0.3), // Study coral
//        animated: Bool = true,
//        animationSpeed: Double = 3.0
//    ) {
//        self.primaryColor = primaryColor
//        self.secondaryColor = secondaryColor
//        self.accentColor = accentColor
//        self.animated = animated
//        self.animationSpeed = animationSpeed
//    }
//    
//    var body: some View {
//        TimelineView(.animation) { timeline in
//            Canvas { context, size in
//                // Calculate animation phase directly without DispatchQueue
//                let timeInterval = timeline.date.timeIntervalSince1970
//                let currentAnimationPhase = animated ?
//                    (timeInterval.truncatingRemainder(dividingBy: 100) / 100 * animationSpeed) :
//                    animationPhase
//                
//                // Create mesh points
//                let points = createMeshPoints(in: size, phase: currentAnimationPhase)
//                
//                // Draw gradient mesh
//                drawMeshGradient(context: context, size: size, points: points, phase: currentAnimationPhase)
//            }
//            .blur(radius: 30)
//            .opacity(0.85)
//        }
//    }
//    
//    private func createMeshPoints(in size: CGSize, phase: Double) -> [[CGPoint]] {
//        let rows = 5
//        let cols = 5
//        
//        var points = [[CGPoint]]()
//        
//        for row in 0..<rows {
//            var rowPoints = [CGPoint]()
//            for col in 0..<cols {
//                // Basic position
//                var x = size.width * CGFloat(col) / CGFloat(cols - 1)
//                var y = size.height * CGFloat(row) / CGFloat(rows - 1)
//                
//                // Add subtle movement to each point if animated
//                if animated {
//                    let xOffset = sin(phase + Double(row + col)) * Double(size.width * 0.05)
//                    let yOffset = cos(phase + Double(row * col)) * Double(size.height * 0.05)
//                    
//                    x += CGFloat(xOffset)
//                    y += CGFloat(yOffset)
//                }
//                
//                rowPoints.append(CGPoint(x: x, y: y))
//            }
//            points.append(rowPoints)
//        }
//        
//        return points
//    }
//    
//    private func drawMeshGradient(context: GraphicsContext, size: CGSize, points: [[CGPoint]], phase: Double) {
//        // Create color stops for our gradient
//        let colorStops: [(offset: CGFloat, color: Color)] = [
//            (0.0, primaryColor),
//            (0.3, secondaryColor),
//            (0.6, primaryColor.opacity(0.8)),
//            (0.9, accentColor.opacity(0.7))
//        ]
//        
//        for row in 0..<(points.count - 1) {
//            for col in 0..<(points[row].count - 1) {
//                let quad = [
//                    points[row][col],
//                    points[row][col + 1],
//                    points[row + 1][col + 1],
//                    points[row + 1][col]
//                ]
//                
//                // Determine which color to use based on position
//                let rowProgress = CGFloat(row) / CGFloat(points.count - 1)
//                let colProgress = CGFloat(col) / CGFloat(points[row].count - 1)
//                let position = (rowProgress + colProgress) / 2
//                
//                // Find the correct color based on position
//                var currentColor = colorStops[0].color
//                for i in 1..<colorStops.count {
//                    if position <= colorStops[i].offset {
//                        let t = (position - colorStops[i-1].offset) / (colorStops[i].offset - colorStops[i-1].offset)
//                        currentColor = blend(color1: colorStops[i-1].color, color2: colorStops[i].color, factor: t)
//                        break
//                    }
//                }
//                
//                // Add variation to each cell for more organic look
//                let hueShift = sin(Double(row * col) * 0.1 + phase) * 0.1
//                let brightnessShift = cos(Double(row + col) * 0.2 + phase) * 0.1
//                
//                let finalColor = adjustColor(color: currentColor, hueShift: hueShift, brightnessShift: brightnessShift)
//                
//                // Draw quad with gradient
//                context.fill(Path { path in
//                    path.move(to: quad[0])
//                    for i in 1..<quad.count {
//                        path.addLine(to: quad[i])
//                    }
//                    path.closeSubpath()
//                }, with: .color(finalColor))
//            }
//        }
//    }
//    
//    // Helper function to blend colors
//    private func blend(color1: Color, color2: Color, factor: CGFloat) -> Color {
//        // Using UIColor for color conversion
//        guard let uiColor1 = UIColor(color1).cgColor.components,
//              let uiColor2 = UIColor(color2).cgColor.components else {
//            return color1
//        }
//        
//        // Simple linear interpolation between colors
//        let red = uiColor1[0] + (uiColor2[0] - uiColor1[0]) * factor
//        let green = uiColor1[1] + (uiColor2[1] - uiColor1[1]) * factor
//        let blue = uiColor1[2] + (uiColor2[2] - uiColor1[2]) * factor
//        let alpha = uiColor1[3] + (uiColor2[3] - uiColor1[3]) * factor
//        
//        return Color(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
//    }
//    
//    // Helper function to adjust color
//    private func adjustColor(color: Color, hueShift: Double, brightnessShift: Double) -> Color {
//        let uiColor = UIColor(color)
//        
//        var hue: CGFloat = 0
//        var saturation: CGFloat = 0
//        var brightness: CGFloat = 0
//        var alpha: CGFloat = 0
//        
//        if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
//            // Apply the shifts
//            hue = CGFloat((Double(hue) + hueShift).truncatingRemainder(dividingBy: 1.0))
//            brightness = max(0, min(1, CGFloat(Double(brightness) + brightnessShift)))
//            
//            return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha))
//        }
//        
//        return color
//    }
//}
//
//// MARK: - Example Usage
//
//// For button background
//struct StudyGuardGradientButton: View {
//    let title: String
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            Text(title)
//                .fontWeight(.semibold)
//                .foregroundColor(.white)
//                .padding(.vertical, 12)
//                .padding(.horizontal, 24)
//                .background {
//                    StudyGuardMeshGradient()
//                        .clipShape(RoundedRectangle(cornerRadius: 12))
//                }
//        }
//    }
//}
//
//// Preview
//struct StudyGuardMeshGradient_Previews: PreviewProvider {
//    static var previews: some View {
//        VStack(spacing: 30) {
//            // Preview the gradient itself
//            StudyGuardMeshGradient()
//                .frame(width: 300, height: 200)
//                .clipShape(RoundedRectangle(cornerRadius: 20))
//            
//            // Preview a button using the gradient
//            StudyGuardGradientButton(title: "Start Study Session") {
//                print("Button tapped!")
//            }
//            
//            // Preview with different colors
//            StudyGuardMeshGradient(
//                primaryColor: .purple,
//                secondaryColor: .blue,
//                accentColor: .pink
//            )
//            .frame(width: 300, height: 100)
//            .clipShape(Capsule())
//        }
//        .padding()
//        .preferredColorScheme(.light)
//    }
//}
