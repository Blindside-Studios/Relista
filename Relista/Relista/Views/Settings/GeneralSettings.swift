//
//  GeneralSettings.swift
//  Relista
//
//  Created by Nicolas Helbig on 30.11.25.
//

import SwiftUI

struct GeneralSettings: View {
    @AppStorage("ShowUserMessageToolbars") private var showUserMessageToolbars: Bool = false
    @AppStorage("AlwaysShowFullModelMessageToolbar") private var alwaysShowFullModelMessageToolbar: Bool = false
    @AppStorage("HapticFeedbackForMessageGeneration") private var vibrateOnTokensReceived: Bool = true
    
    var body: some View {
        List{
            Section(header: Text("Response Display"), footer: Text("Only applies to bigger screens where information is displayed in-line")){
                Toggle("Show user message toolbars", isOn: $showUserMessageToolbars)
                Toggle("Always show time and model", isOn: $alwaysShowFullModelMessageToolbar)
            }
            
            // haptic feedback only applies to iPhone
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                Section(header: Text("Haptic Feedback")){
                    Toggle("Haptic feedback during response generation", isOn: $vibrateOnTokensReceived)
                }
            }
            #endif
        }
    }
}

#Preview {
    GeneralSettings()
}
