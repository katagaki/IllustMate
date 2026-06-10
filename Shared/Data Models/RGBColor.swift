struct RGBColor: Equatable {
    let red: Int
    let green: Int
    let blue: Int
}

extension RGBColor {
    var saturation: Double {
        let maxC = Double(max(red, green, blue))
        let minC = Double(min(red, green, blue))
        guard maxC > 0 else { return 0 }
        return (maxC - minC) / maxC
    }

    var brightness: Double {
        Double(max(red, green, blue)) / 255.0
    }

    var hue: Double {
        let r = Double(red) / 255.0
        let g = Double(green) / 255.0
        let b = Double(blue) / 255.0
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        guard delta > 0 else { return 0 }
        var hue: Double
        if maxC == r {
            hue = (g - b) / delta
        } else if maxC == g {
            hue = 2 + (b - r) / delta
        } else {
            hue = 4 + (r - g) / delta
        }
        hue *= 60
        if hue < 0 { hue += 360 }
        return hue
    }

    var sortKey: (Int, Double, Double) {
        if saturation < 0.12 {
            return (1, brightness, 0)
        }
        return (0, hue, brightness)
    }
}

struct PicColors: Equatable {
    let primary: RGBColor
    let accent: RGBColor
    let contrasting: RGBColor
}

extension PicColors: Comparable {
    static func < (lhs: PicColors, rhs: PicColors) -> Bool {
        if lhs.primary.sortKey != rhs.primary.sortKey {
            return lhs.primary.sortKey < rhs.primary.sortKey
        }
        if lhs.accent.sortKey != rhs.accent.sortKey {
            return lhs.accent.sortKey < rhs.accent.sortKey
        }
        return lhs.contrasting.sortKey < rhs.contrasting.sortKey
    }
}
