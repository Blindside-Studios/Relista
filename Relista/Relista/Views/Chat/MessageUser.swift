//
//  MessageUser.swift
//  Relista
//
//  Created by Nicolas Helbig on 02.11.25.
//

import SwiftUI

struct MessageUser: View {
    let message: Message
    let availableWidth: CGFloat
    
    var body: some View {
        VStack{
            HStack {
                Spacer(minLength: availableWidth * 0.2)
                
                Text(message.text)
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 25.0))
                    .foregroundStyle(message.role == .system ? Color.orange : Color.primary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal)
            
            Spacer()
                .frame(minWidth: 0)
        }
    }
}

#Preview {
    //MessageUser(messageText: "Assistant message", availableWidth: 200)
}
