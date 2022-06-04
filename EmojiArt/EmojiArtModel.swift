//
//  EmojiArtModel.swift
//  EmojiArt
//
//  Created by CS193p Instructor on 4/26/21.
//  Copyright © 2021 Stanford University. All rights reserved.
//

import Foundation

struct EmojiArtModel {
    var background = Background.blank
    var emojis = [Emoji]()
    var selection = [Emoji]()
    
    struct Emoji: Identifiable, Hashable {
        let text: String
        var x: Int // offset from the center
        var y: Int // offset from the center
        var size: Int
        let id: Int
        
        fileprivate init(text: String, x: Int, y: Int, size: Int, id: Int) {
            self.text = text
            self.x = x
            self.y = y
            self.size = size
            self.id = id
        }
    }
    
    init() { }
    
    private var uniqueEmojiId = 0
    
    mutating func addEmoji(_ text: String, at location: (x: Int, y: Int), size: Int) {
        uniqueEmojiId += 1
        emojis.append(Emoji(text: text, x: location.x, y: location.y, size: size, id: uniqueEmojiId))
    }
    
    mutating func removeEmoji(emoji: Emoji) {
        if let index = emojis.index(matching: emoji) {
            emojis.remove(at: index)
        }
    }
    
    mutating func addOrRemoveFromSelection(emoji: Emoji) {
        if let index = selection.index(matching: emoji) {
            selection.remove(at: index)
        } else {
            selection.append(emoji)
        }
        print(selection)
    }
    
    mutating func deselectAllEmoji() {
        selection.removeAll()
    }
}
