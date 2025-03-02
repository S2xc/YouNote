//
//  YouNoteApp.swift
//  YouNote
//
//  Created by s2x on 02.03.2025.
//

import SwiftUI
import SwiftData

@main
struct YouNoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: Note.self)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    NotificationCenter.default.post(name: .init("createNewNote"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandMenu("Format") {
                Menu("Text Style") {
                    Button("Title") { applyStyle("title") }
                    Button("Heading") { applyStyle("heading") }
                    Button("Body") { applyStyle("body") }
                    Button("Code") { applyStyle("code") }
                }
                
                Divider()
                
                Button("Bold") { applyStyle("bold") }
                    .keyboardShortcut("b", modifiers: .command)
                
                Button("Italic") { applyStyle("italic") }
                    .keyboardShortcut("i", modifiers: .command)
                
                Button("Underline") { applyStyle("underline") }
                    .keyboardShortcut("u", modifiers: .command)
            }
        }
    }
    
    private func applyStyle(_ style: String) {
        // Будет реализовано позже для форматирования текста
        NotificationCenter.default.post(name: .init("applyTextStyle"), object: style)
    }
}
