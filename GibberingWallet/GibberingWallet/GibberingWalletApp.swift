//
//  GibberingWalletApp.swift
//  GibberingWallet
//
//  Created by Se Bas on 12/7/25.
//

import SwiftUI

@main
struct GibberingWalletApp: App {
    @StateObject private var walletManager = WalletManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(walletManager)
        }
    }
}
