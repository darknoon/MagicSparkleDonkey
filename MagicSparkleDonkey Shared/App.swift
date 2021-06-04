//
//  App.swift
//  MagicSparkleDonkey
//
//  Created by Andrew Pouliot on 5/18/21.
//

import SwiftUI

@main
struct MSDApp : App {
    var body: some SwiftUI.Scene {
        WindowGroup {
            MSDView()
                .edgesIgnoringSafeArea(.all)
        }
    }
}
