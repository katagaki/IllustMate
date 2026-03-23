//
//  ScrollViewInterop.swift
//  PicMate
//
//  Created by Claude on 2026/03/23.
//

import SwiftUI

/// Workaround for a SwiftUI bug where the large navigation bar title
/// can get stuck mid-transition when scrolling a view with grid content.
///
/// This helper introspects the underlying UIScrollView and forces
/// `contentInsetAdjustmentBehavior = .always`, which ensures UIKit
/// keeps the navigation bar and scroll view in sync during the
/// large-to-inline title animation.
struct ScrollViewInterop: UIViewRepresentable {

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = Self.enclosingScrollView(of: uiView) else { return }
            scrollView.contentInsetAdjustmentBehavior = .always
        }
    }

    private static func enclosingScrollView(of view: UIView) -> UIScrollView? {
        var current: UIView? = view
        while let superview = current?.superview {
            if let scrollView = superview as? UIScrollView {
                return scrollView
            }
            current = superview
        }
        return nil
    }
}

extension View {
    func fixNavigationHeaderTransition() -> some View {
        background(ScrollViewInterop())
    }
}
