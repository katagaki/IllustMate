//
//  AuthenticationManager.swift
//  PicMate
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import LocalAuthentication
import SwiftUI

@MainActor @Observable
class AuthenticationManager {

    var isUnlocked: Bool = false
    var isAuthenticating: Bool = false

    var biometryType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    func authenticate() {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            isUnlocked = true
            return
        }

        isAuthenticating = true
        let reason = String(localized: "Auth.Reason")

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                if success {
                    self.isUnlocked = true
                }
            }
        }
    }

    func lock() {
        isUnlocked = false
    }
}
