//
//  ChatBackground.swift
//  Relista
//
//  Created by Nicolas Helbig on 07.01.26.
//

import SwiftUI

struct ChatBackground: View {
    @Binding var selectedAgent: UUID?
    @Binding var selectedChat: UUID
    @Binding var primaryAccentColor: Color
    @Binding var secondaryAccentColor: Color
    @State var primaryColor: Color = .clear
    @State var secondaryColor: Color = .clear
    
    var body: some View {
        ZStack{
            if selectedAgent != nil{
                Jellyfish(primaryColor: $primaryColor, secondaryColor: $secondaryColor, selectedChat: $selectedChat)
                    .transition(.opacity.combined(with: .scale(scale: 5)))
            }
        }
        .animation(.default, value: selectedAgent)
        .animation(.default, value: primaryColor)
        .animation(.default, value: secondaryColor)
        .task(id: selectedChat){
            loadAgentColors()
        }
    }
    
    private func loadAgentColors(){
        if selectedAgent != nil{
            let colorResponse = AgentManager.getUIAgentColors(fromUUID: selectedAgent!)
            debugPrint(colorResponse)

            if let primaryHex = colorResponse[0], let secondaryHex = colorResponse[1] {
                let cleanPrimary = primaryHex.replacingOccurrences(of: "#", with: "")
                let cleanSecondary = secondaryHex.replacingOccurrences(of: "#", with: "")
                
                primaryColor = Color(hex: cleanPrimary) ?? .clear
                secondaryColor = Color(hex: cleanSecondary) ?? .clear
                
                primaryAccentColor = Color(hex: cleanPrimary) ?? .clear
                secondaryAccentColor = Color(hex: cleanSecondary) ?? .primary
            } else {
                primaryAccentColor = .clear
                secondaryColor = .primary
                primaryColor = .clear
                secondaryColor = .clear
            }
        } else {
            primaryAccentColor = .clear
            secondaryAccentColor = .primary
            primaryColor = .clear
            secondaryColor = .clear
        }
    }
}

#Preview {
    //hatBackground()
}
