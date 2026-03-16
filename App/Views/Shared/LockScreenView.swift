//
//  LockScreenView.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import SwiftUI

struct LockScreenView: View {

    @Environment(AuthenticationManager.self) var auth

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            VStack(spacing: 24.0) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48.0))
                    .foregroundStyle(.secondary)
                Text("Auth.Locked")
                    .font(.title3)
                Button {
                    auth.authenticate()
                } label: {
                    Label("Auth.Unlock", systemImage: biometryIcon)
                        .font(.body.bold())
                        .padding(.horizontal, 8.0)
                        .padding(.vertical, 4.0)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(.accent)
                .disabled(auth.isAuthenticating)
            }
        }
    }

    var biometryIcon: String {
        switch auth.biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "lock.open"
        }
    }
}
