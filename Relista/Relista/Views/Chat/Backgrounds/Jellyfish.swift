//
//  Jellyfish.swift
//  Relista
//
//  Created by Nicolas Helbig on 07.01.26.
//

import SwiftUI

struct Jellyfish: View {
    @Binding var primaryColor: Color
    @Binding var secondaryColor: Color
    @Binding var selectedChat: UUID
    
    private var isChatBlank: Bool{
        ChatCache.shared.loadedChats[selectedChat]?.messages.isEmpty ?? false
    }
    var cornerRadius: Int{
        #if os(macOS)
        24
        #else
        if UIDevice.current.userInterfaceIdiom == .pad{
            18
        }
        else if UIDevice.current.userInterfaceIdiom == .phone{
            59
        } else {
            0
        }
        #endif
    }
        
    var body: some View {
        ZStack{
            Rectangle()
                .fill(primaryColor)
                .mask(){
                    Rectangle()
                        .overlay {
                            RoundedRectangle(cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: .continuous)
                                .blur(radius: isChatBlank ? 40 : 30)
                                .opacity(isChatBlank ? 0.6 : 0.9)
                                .blendMode(.destinationOut)
                            RoundedRectangle(cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: .continuous)
                                .blur(radius: isChatBlank ? 40 : 20)
                                .opacity(isChatBlank ? 0.6 : 0.7)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                .opacity(isChatBlank ? 1 : 0.8)
                .onChange(of: selectedChat, {_ = isChatBlank})
                .ignoresSafeArea()
            
            if isChatBlank{
                AmbientBackground(accentColor: $secondaryColor)
                    .blur(radius: 100)
                    .transition(.opacity.combined(with: .scale(scale: 5)))
            }
        }
        .animation(.default, value: isChatBlank)
    }
    
    struct FloatingOrb: View {
        @Binding var color: Color
        let size: CGFloat
        let duration: Double
        
        @State private var offsetX: CGFloat = 0
        @State private var offsetY: CGFloat = 0
        @State private var scale: CGFloat = 1.0
        
        var body: some View {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(1), color.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: 15)
                .scaleEffect(scale)
                .offset(x: offsetX, y: offsetY)
                .onAppear {
                    // Random drift animation
                    withAnimation(
                        .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true)
                    ) {
                        offsetX = CGFloat.random(in: -100...100)
                        offsetY = CGFloat.random(in: -100...100)
                    }
                    
                    // Gentle pulse
                    withAnimation(
                        .easeInOut(duration: duration * 0.6)
                        .repeatForever(autoreverses: true)
                    ) {
                        scale = CGFloat.random(in: 0.8...1.2)
                    }
                }
        }
    }

    struct AmbientBackground: View {
        @Binding var accentColor: Color
        @State private var rotation: Double = 0
        
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    FloatingOrb(color: $accentColor, size: 250, duration: 8)
                        .position(x: width * 0.2, y: height * 0.3)

                    FloatingOrb(color: $accentColor, size: 200, duration: 12)
                        .opacity(0.8)
                        .position(x: width * 0.8, y: height * 0.6)

                    FloatingOrb(color: $accentColor, size: 220, duration: 10)
                        .opacity(0.6)
                        .position(x: width * 0.5, y: height * 0.2)

                    FloatingOrb(color: $accentColor, size: 210, duration: 14)
                        .opacity(0.7)
                        .position(x: width * 0.15, y: height * 0.7)

                    FloatingOrb(color: $accentColor, size: 180, duration: 9)
                        .opacity(0.9)
                        .position(x: width * 0.75, y: height * 0.25)

                    FloatingOrb(color: $accentColor, size: 240, duration: 11)
                        .opacity(0.75)
                        .position(x: width * 0.6, y: height * 0.8)
                }
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(
                        .linear(duration: 60)
                        .repeatForever(autoreverses: false)
                    ) {
                        rotation = 360
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }
}

#Preview {
    Jellyfish(primaryColor: .constant(.red), secondaryColor: .constant(.blue), selectedChat: .constant(UUID()))
        //.frame(width: 700, height: 500)
        .ignoresSafeArea()
}
