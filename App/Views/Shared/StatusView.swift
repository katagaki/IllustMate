//
//  StatusView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/02/24.
//

import SwiftUI

struct StatusView: View {

    var type: StatusType
    var title: LocalizedStringKey
    var message: LocalizedStringKey?
    var currentCount: Int?
    var totalCount: Int?

    enum StatusType {
        case inProgress
        case success
        case error
    }

    var body: some View {
        VStack(alignment: .center, spacing: 20.0) {
            Spacer()
            switch type {
            case .inProgress:
                if let currentCount, let totalCount {
                    VStack(alignment: .center, spacing: 16.0) {
                        Text(title)
                            .bold()
                            .frame(maxWidth: .infinity)
                        ProgressView(value: Float(currentCount), total: Float(totalCount))
                            .progressViewStyle(.linear)
                    }
                } else {
                    VStack(alignment: .center, spacing: 16.0) {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text(title)
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                }
            case .success:
                VStack(alignment: .center, spacing: 16.0) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64.0, height: 64.0)
                        .symbolRenderingMode(.multicolor)
                    Text(title)
                        .bold()
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    if let message {
                        Text(message)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
            case .error:
                VStack(alignment: .center, spacing: 16.0) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64.0, height: 64.0)
                        .symbolRenderingMode(.multicolor)
                    Text(title)
                        .bold()
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    if let message {
                        Text(message)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            Spacer()
        }
        .padding(20.0)
        .frame(maxWidth: .infinity)
    }
}
