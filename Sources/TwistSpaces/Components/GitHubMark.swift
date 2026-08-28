import SwiftUI

// GitHub Mark, converted from https://github.com/primer/octicons/blob/main/icons/mark-github-16.svg.
// Original artwork is MIT licensed; see Resources/Octicons-LICENSE.txt.
struct GitHubMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 6.766, y: 11.328))
        path.addCurve(to: CGPoint(x: 3.25, y: 7.672), control1: CGPoint(x: 4.703, y: 11.078), control2: CGPoint(x: 3.25, y: 9.594))
        path.addCurve(to: CGPoint(x: 4, y: 5.484), control1: CGPoint(x: 3.25, y: 6.891), control2: CGPoint(x: 3.531, y: 6.047))
        path.addCurve(to: CGPoint(x: 4.063, y: 3.422), control1: CGPoint(x: 3.797, y: 4.969), control2: CGPoint(x: 3.828, y: 3.875))
        path.addCurve(to: CGPoint(x: 6.031, y: 4.125), control1: CGPoint(x: 4.688, y: 3.344), control2: CGPoint(x: 5.531, y: 3.672))
        path.addCurve(to: CGPoint(x: 8.016, y: 3.844), control1: CGPoint(x: 6.625, y: 3.938), control2: CGPoint(x: 7.25, y: 3.844))
        path.addCurve(to: CGPoint(x: 9.969, y: 4.109), control1: CGPoint(x: 8.781, y: 3.844), control2: CGPoint(x: 9.406, y: 3.938))
        path.addCurve(to: CGPoint(x: 11.938, y: 3.422), control1: CGPoint(x: 10.453, y: 3.672), control2: CGPoint(x: 11.313, y: 3.344))
        path.addCurve(to: CGPoint(x: 11.984, y: 5.469), control1: CGPoint(x: 12.156, y: 3.844), control2: CGPoint(x: 12.188, y: 4.937))
        path.addCurve(to: CGPoint(x: 12.75, y: 7.672), control1: CGPoint(x: 12.484, y: 6.062), control2: CGPoint(x: 12.75, y: 6.859))
        path.addCurve(to: CGPoint(x: 9.203, y: 11.312), control1: CGPoint(x: 12.75, y: 9.594), control2: CGPoint(x: 11.297, y: 11.047))
        path.addCurve(to: CGPoint(x: 10.093, y: 13.266), control1: CGPoint(x: 9.734, y: 11.656), control2: CGPoint(x: 10.093, y: 12.406))
        path.addLine(to: CGPoint(x: 10.093, y: 14.891))
        path.addCurve(to: CGPoint(x: 10.953, y: 15.438), control1: CGPoint(x: 10.093, y: 15.359), control2: CGPoint(x: 10.484, y: 15.625))
        path.addCurve(to: CGPoint(x: 16, y: 8.03), control1: CGPoint(x: 13.781, y: 14.359), control2: CGPoint(x: 16, y: 11.53))
        path.addCurve(to: CGPoint(x: 7.984, y: 0), control1: CGPoint(x: 16, y: 3.61), control2: CGPoint(x: 12.406, y: 0))
        path.addCurve(to: CGPoint(x: 0, y: 8.031), control1: CGPoint(x: 3.563, y: 0), control2: CGPoint(x: 0, y: 3.61))
        path.addCurve(to: CGPoint(x: 5.172, y: 15.453), control1: CGPoint(x: -0.00922, y: 11.346744), control2: CGPoint(x: 2.058182, y: 14.313537))
        path.addCurve(to: CGPoint(x: 6, y: 14.906), control1: CGPoint(x: 5.594, y: 15.609), control2: CGPoint(x: 6, y: 15.328))
        path.addLine(to: CGPoint(x: 6, y: 13.656))
        path.addCurve(to: CGPoint(x: 5.25, y: 13.812), control1: CGPoint(x: 5.781, y: 13.75), control2: CGPoint(x: 5.5, y: 13.812))
        path.addCurve(to: CGPoint(x: 3.172, y: 12.203), control1: CGPoint(x: 4.219, y: 13.812), control2: CGPoint(x: 3.61, y: 13.25))
        path.addCurve(to: CGPoint(x: 2.453, y: 11.484), control1: CGPoint(x: 3, y: 11.781), control2: CGPoint(x: 2.812, y: 11.531))
        path.addCurve(to: CGPoint(x: 2.203, y: 11.297), control1: CGPoint(x: 2.266, y: 11.469), control2: CGPoint(x: 2.203, y: 11.391))
        path.addCurve(to: CGPoint(x: 2.828, y: 10.969), control1: CGPoint(x: 2.203, y: 11.109), control2: CGPoint(x: 2.516, y: 10.969))
        path.addCurve(to: CGPoint(x: 4.078, y: 11.829), control1: CGPoint(x: 3.281, y: 10.969), control2: CGPoint(x: 3.672, y: 11.25))
        path.addCurve(to: CGPoint(x: 5.109, y: 12.484), control1: CGPoint(x: 4.391, y: 12.281), control2: CGPoint(x: 4.718, y: 12.484))
        path.addCurve(to: CGPoint(x: 6.109, y: 11.984), control1: CGPoint(x: 5.5, y: 12.484), control2: CGPoint(x: 5.75, y: 12.344))
        path.addCurve(to: CGPoint(x: 6.766, y: 11.328), control1: CGPoint(x: 6.375, y: 11.719), control2: CGPoint(x: 6.579, y: 11.484))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: rect.width / 16, y: rect.height / 16))
            .offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

