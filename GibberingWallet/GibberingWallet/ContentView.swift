//
//  ContentView.swift
//  GibberingWallet
//
//  Created by Se Bas on 12/7/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var walletManager: WalletManager
    
    var body: some View {
        NavigationView {
            if walletManager.currentWallet == nil {
                WalletSetupView()
            } else {
                MainWalletView()
            }
        }
        .onAppear {
            walletManager.loadWallet()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WalletManager())
}
