//
//  DurationFormatter.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/04/02.
//

import Foundation

func formatDuration(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds.rounded())
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}
