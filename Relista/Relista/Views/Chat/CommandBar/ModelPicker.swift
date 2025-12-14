//
//  ModelPicker.swift
//  Relista
//
//  Created by Nicolas Helbig on 13.12.25.
//

import SwiftUI

struct ModelPicker: View {
    @Namespace private var ModelPickerTransition
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var showModelPickerPopOver = false
    @State private var showModelPickerSheet = false
    @Binding var selectedModel: String
    
    @State private var internalModelRepresentation = ModelList.getModelFromSlug(slug: ModelList.placeHolderModel)
    
    var body: some View {
        Button{
            if horizontalSizeClass == .compact { showModelPickerSheet = true }
            else { showModelPickerPopOver.toggle() }
        } label: {
            VStack(alignment: .center, spacing: -2) {
                if let family = internalModelRepresentation.family,
                   let spec = internalModelRepresentation.specifier {
                    
                    Text(family)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(spec)
                        .font(.caption)
                } else {
                    Text(internalModelRepresentation.name)
                        .font(.caption)
                }
            }
            .bold()
            .onAppear(perform: refreshModelDisplay)
            .onChange(of: ModelList.areModelsLoaded, refreshModelDisplay)
            .onChange(of: selectedModel, refreshModelDisplay)
        }
        .buttonStyle(.plain)
        .labelStyle(.titleOnly)
        .matchedTransitionSource(
            id: "model", in: ModelPickerTransition
        )
        .popover(isPresented: $showModelPickerPopOver) {
            ModelPickerContents(
                selectedModelSlug: $selectedModel,
                isOpen: $showModelPickerPopOver
            )
            .frame(minWidth: 250, maxHeight: 450)
        }
        #if os(iOS)
        /// only show this on iOS because the other platforms use a popover,
        /// the differentiation exists such that we can use a matched gemoetry effect,
        /// which is not possible on popover and is much less possible on macOS anyways.
        .sheet(isPresented: $showModelPickerSheet) {
            ModelPickerContents(
                selectedModelSlug: $selectedModel,
                isOpen: $showModelPickerSheet
            )
            .presentationDetents([.medium, .large])
            
            .navigationTransition(
                .zoom(sourceID: "model", in: ModelPickerTransition)
            )
        }
        #endif
    }
    
    private func refreshModelDisplay(){
        internalModelRepresentation = ModelList.getModelFromSlug(slug: selectedModel)
    }
}

struct ModelPickerContents: View {
    @Binding var selectedModelSlug: String
    @Binding var isOpen: Bool

    var body: some View {
        ScrollView(.vertical){
            ForEach(ModelList.AllModels){ model in
                HStack{
                    VStack(alignment: .leading, spacing: 0.0) {
                        Text(model.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(model.modelID)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.vertical, 4.0)
                .padding(.horizontal, 8.0)
                .background(selectedModelSlug == model.modelID ? AnyShapeStyle(.thickMaterial) : AnyShapeStyle(.clear))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedModelSlug = model.modelID
                    isOpen = false
                }
            }
            .padding(8)
        }
    }
}

#Preview {
    //ModelPicker()
}
