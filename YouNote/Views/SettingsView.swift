import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("fontName") private var fontName: String = "SF Pro"
    @AppStorage("fontSize") private var fontSize: Double = 16.0
    @AppStorage("accentColor") private var accentColor: String = "blue"
    @AppStorage("enableAutoSave") private var enableAutoSave: Bool = true
    @AppStorage("autoSaveInterval") private var autoSaveInterval: Double = 5.0
    @AppStorage("defaultCategory") private var defaultCategory: String = "Uncategorized"
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    
    @Query private var notes: [Note]
    
    @State private var showDeleteAlert = false
    @State private var showExportImport = false
    
    var allCategories: [String] {
        Array(Set(notes.map { $0.category })).sorted()
    }
    
    private let availableFonts = ["SF Pro", "New York", "Helvetica Neue", "Times New Roman", "Courier"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Font", selection: $fontName) {
                        ForEach(availableFonts, id: \.self) { font in
                            Text(font)
                                .tag(font)
                        }
                    }
                    
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(fontSize))")
                            .foregroundStyle(.secondary)
                        Slider(value: $fontSize, in: 12...24, step: 1)
                            .frame(width: 150)
                    }
                    
                    Picker("Accent Color", selection: $accentColor) {
                        HStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 16, height: 16)
                            Text("Blue")
                        }
                        .tag("blue")
                        
                        HStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 16, height: 16)
                            Text("Green")
                        }
                        .tag("green")
                        
                        HStack {
                            Circle()
                                .fill(.orange)
                                .frame(width: 16, height: 16)
                            Text("Orange")
                        }
                        .tag("orange")
                        
                        HStack {
                            Circle()
                                .fill(.purple)
                                .frame(width: 16, height: 16)
                            Text("Purple")
                        }
                        .tag("purple")
                        
                        HStack {
                            Circle()
                                .fill(.pink)
                                .frame(width: 16, height: 16)
                            Text("Pink")
                        }
                        .tag("pink")
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Auto Save") {
                    Toggle("Enable Auto Save", isOn: $enableAutoSave)
                    
                    if enableAutoSave {
                        HStack {
                            Text("Save Interval")
                            Spacer()
                            Text("\(Int(autoSaveInterval)) seconds")
                                .foregroundStyle(.secondary)
                            Slider(value: $autoSaveInterval, in: 1...30, step: 1)
                                .frame(width: 150)
                        }
                    }
                }
                
                Section("Default Settings") {
                    Picker("Default Category", selection: $defaultCategory) {
                        ForEach(allCategories, id: \.self) { category in
                            Text(category)
                                .tag(category)
                        }
                    }
                }
                
                Section("Data Management") {
                    NavigationLink(destination: NoteExportImportView()) {
                        Label("Import/Export Notes", systemImage: "square.and.arrow.up.on.square")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete All Notes", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Delete All Notes", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAllNotes()
                }
            } message: {
                Text("Are you sure you want to delete all notes? This action cannot be undone.")
            }
        }
    }
    
    private func deleteAllNotes() {
        for note in notes {
            context.delete(note)
        }
        
        do {
            try context.save()
        } catch {
            print("Error deleting notes: \(error)")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Note.self, inMemory: true)
}
