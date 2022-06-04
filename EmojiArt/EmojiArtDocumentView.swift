//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by CS193p Instructor on 4/26/21.
//  Copyright © 2021 Stanford University. All rights reserved.
//  Some credit to skkimeo for generics

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    private let defaultEmojiFontSize: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            palette
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            if #available(iOS 15.0, *) {
                ZStack {
                    Color.white
                        .overlay(
                            OptionalImage(uiImage: document.backgroundImage)
                                .scaleEffect(document.selection.isEmpty ? zoomScale : steadyStateZoomScale)
                                .position(convertFromEmojiCoordinates((0, 0), in: geometry))
                        )
                        .gesture(doubleTapToZoom(in: geometry.size).exclusively(before: tapToUnselectAllEmojis()))
                    if document.backgroundImageFetchStatus == .fetching {
                        ProgressView().scaleEffect(2)
                    } else {
                        ForEach(document.emojis) { emoji in
                            Text(emoji.text)
                                .font(.system(size: fontSize(for: emoji)))
                                .selectionEffect(for: emoji, in: document.selection)
                                .scaleEffect(getZoomScaleForEmoji(emoji))
                                .position(position(for: emoji, in: geometry))
                                .gesture(selectionGesture(on: emoji).simultaneously(with: doubleTapToDelete(on: emoji).simultaneously(with: document.selection.contains(emoji) ? panEmojiGesture(on: emoji) : nil)))
                        }
                    }
                }
                .clipped()
                .onDrop(of: [.plainText, .url, .image], isTargeted: nil) { providers, location in
                    drop(providers: providers, at: location, in: geometry)
                }
                .gesture(zoomGesture().simultaneously(with: gestureEmojiPanOffset == CGSize.zero ? panGesture() : nil))
            }
        }
    }
    
    // MARK: - Drag and Drop
    
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        var found = providers.loadObjects(ofType: URL.self) { url in
            document.setBackground(.url(url.imageURL))
        }
        if !found {
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    document.setBackground(.imageData(data))
                }
            }
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale)
                }
            }
        }
        return found
    }
    
    // MARK: - Positioning/Sizing Emoji
    
    private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        CGFloat(emoji.size)
    }
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        if document.selection.contains(emoji) {
            return convertFromEmojiCoordinates((emoji.x + Int(gestureEmojiPanOffset.width), emoji.y + Int(gestureEmojiPanOffset.height)), in: geometry)
        } else {
            return convertFromEmojiCoordinates((emoji.x, emoji.y), in: geometry)
        }
    }
    
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) -> (Int, Int) {
        let center = geometry.frame(in: .local).center
        let location = (
            x: (location.x - center.x - panOffset.width) / zoomScale,
            y: (location.y - center.y - panOffset.height) / zoomScale
        )
        return (Int(location.x), Int(location.y))
    }
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + panOffset.height
        )
    }
    
    // MARK: - Zooming
    
    @State private var steadyStateZoomScale: CGFloat = 1
    @GestureState private var gestureZoomScale: CGFloat = 1
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func getZoomScaleForEmoji(_ emoji: EmojiArtModel.Emoji) -> CGFloat {
        document.selection.isEmpty ? zoomScale : document.selection.contains(emoji) ? zoomScale : steadyStateZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, _ in
                gestureZoomScale = latestGestureScale
            }
            .onEnded { gestureScaleAtEnd in
                if document.selection.isEmpty {
                    steadyStateZoomScale *= gestureScaleAtEnd
                } else {
                    for emoji in document.selection {
                        document.scaleEmoji(emoji, by: gestureScaleAtEnd)
                    }
                }
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(image: document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(image: UIImage?, in size: CGSize) {
        if let image = image, image.size.height > 0, image.size.width > 0,
           size.width > 0, size.height > 0  {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            
            steadyStatePanOffset = CGSize.zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    // MARK: - Panning
    
    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    @GestureState private var gestureEmojiPanOffset: CGSize = CGSize.zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, _ in
                gesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset =  steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    private func panEmojiGesture(on emoji: EmojiArtModel.Emoji) -> some Gesture {
        DragGesture()
            .updating($gestureEmojiPanOffset) { latestDragGestureValue, gestureEmojiPanOffset, _ in
                gestureEmojiPanOffset = latestDragGestureValue.distance / zoomScale
            }
            .onEnded { finalDragGestureValue in
                for emoji in document.selection {
                    document.moveEmoji(emoji, by: finalDragGestureValue.distance / zoomScale)
                }
            }
    }
    
    // MARK: - Selecting/Unselecting Emojis

    
    private func selectionGesture(on emoji: EmojiArtModel.Emoji) -> some Gesture {
        TapGesture()
            .onEnded {
                withAnimation {
                    document.addOrRemoveFromSelection(emoji: emoji)
                }
            }
    }
    
    private func tapToUnselectAllEmojis() -> some Gesture {
        TapGesture()
            .onEnded {
                withAnimation {
                    document.deselectAllEmoji()
                }
            }
    }
    

    
    private func doubleTapToDelete(on emoji: EmojiArtModel.Emoji) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    // remove
                    if document.selection.contains(emoji) {
                        document.addOrRemoveFromSelection(emoji: emoji)
                    }
                    document.removeEmoji(emoji: emoji)
                }
            }
        }
    
    // MARK: - palette
    
    var palette: some View {
        ScrollingEmojisView(emojis: testEmojis)
            .font(.system(size: defaultEmojiFontSize))
    }
    
    let testEmojis = "😀😷🦠💉👻👀🐶🌲🌎🌞🔥🍎⚽️🚗🚓🚲🛩🚁🚀🛸🏠⌚️🎁🗝🔐❤️⛔️❌❓✅⚠️🎶➕➖🏳️"
}

struct ScrollingEmojisView: View {
    let emojis: String

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(emojis.map { String($0) }, id: \.self) { emoji in
                    Text(emoji)
                        .onDrag { NSItemProvider(object: emoji as NSString) }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}

struct SelectionEffect: ViewModifier {
    var emoji: EmojiArtModel.Emoji
    var selectedEmojis: Array<EmojiArtModel.Emoji>
    
    func body(content: Content) -> some View {
        content
            .overlay(
                selectedEmojis.contains(emoji) ? RoundedRectangle(cornerRadius: 0).strokeBorder(lineWidth: 2).foregroundColor(.purple) : nil
            )
    }
}

extension View {
    func selectionEffect(for emoji: EmojiArtModel.Emoji, in selectedEmojis: Array<EmojiArtModel.Emoji>) -> some View {
        modifier(SelectionEffect(emoji: emoji, selectedEmojis: selectedEmojis))
    }
}
