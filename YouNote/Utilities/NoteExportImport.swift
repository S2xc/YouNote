import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Структура для импорта/экспорта заметок
struct NoteData: Codable {
    var title: String
    var content: String
    var tags: [String]
    var category: String
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    var color: String
    
    init(from note: Note) {
        self.title = note.title
        self.content = note.content
        self.tags = note.tags
        self.category = note.category
        self.isFavorite = note.isFavorite
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
        self.color = note.color
    }
    
    func toNote() -> Note {
        return Note(
            title: title,
            content: content,
            tags: tags,
            category: category,
            isFavorite: isFavorite,
            color: color
        )
    }
}

class NoteExportImport {
    static let shared = NoteExportImport()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func exportNote(_ note: Note) -> URL? {
        let noteData = NoteData(from: note)
        
        do {
            let data = try encoder.encode(noteData)
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "\(note.title.replacingOccurrences(of: " ", with: "_")).ynote"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error exporting note: \(error)")
            return nil
        }
    }
    
    func importNote(from url: URL, into context: ModelContext) -> Note? {
        do {
            let data = try Data(contentsOf: url)
            let noteData = try decoder.decode(NoteData.self, from: data)
            
            let note = noteData.toNote()
            context.insert(note)
            return note
        } catch {
            print("Error importing note: \(error)")
            return nil
        }
    }
    
    func exportAllNotes(_ notes: [Note]) -> URL? {
        let notesData = notes.map { NoteData(from: $0) }
        
        do {
            let data = try encoder.encode(notesData)
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "YouNotes_\(Date().formatted(.dateTime.year().month().day())).ynotes"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error exporting notes: \(error)")
            return nil
        }
    }
    
    func importAllNotes(from url: URL, into context: ModelContext) -> [Note] {
        do {
            let data = try Data(contentsOf: url)
            let notesData = try decoder.decode([NoteData].self, from: data)
            
            let notes = notesData.map { noteData -> Note in
                let note = noteData.toNote()
                context.insert(note)
                return note
            }
            
            return notes
        } catch {
            print("Error importing notes: \(error)")
            return []
        }
    }
}

// Расширение для поддержки форматов файлов
extension UTType {
    static let youNote = UTType(exportedAs: "com.younote.note")
    static let youNotes = UTType(exportedAs: "com.younote.notes")
}

// Общий протокол для наших документов экспорта
protocol YouNoteExportable: FileDocument {
    var contentType: UTType { get }
    var fileName: String { get }
}

// Документы для FileExporter
struct NoteDocument: FileDocument, YouNoteExportable {
    let note: Note
    
    static var readableContentTypes: [UTType] { [.youNote] }
    
    var contentType: UTType { .youNote }
    var fileName: String { "\(note.title).ynote" }
    
    init(note: Note) {
        self.note = note
    }
    
    init(configuration: ReadConfiguration) throws {
        // Этот инициализатор нужен для соответствия протоколу, но не будет использоваться
        // для экспорта
        fatalError("Not implemented")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let noteData = NoteData(from: note)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(noteData)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct NotesDocument: FileDocument, YouNoteExportable {
    let notes: [Note]
    
    static var readableContentTypes: [UTType] { [.youNotes] }
    
    var contentType: UTType { .youNotes }
    var fileName: String { "YouNotes_\(Date().formatted(.dateTime.year().month().day())).ynotes" }
    
    init(notes: [Note]) {
        self.notes = notes
    }
    
    init(configuration: ReadConfiguration) throws {
        fatalError("Not implemented")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let notesData = notes.map { NoteData(from: $0) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(notesData)
        return FileWrapper(regularFileWithContents: data)
    }
}

// Обертка для наших документов, чтобы решить проблему различных типов
enum ExportDocumentWrapper: FileDocument {
    case single(NoteDocument)
    case multiple(NotesDocument)
    
    static var readableContentTypes: [UTType] { [.youNote, .youNotes] }
    
    init(configuration: ReadConfiguration) throws {
        fatalError("Not implemented")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        switch self {
        case .single(let document):
            return try document.fileWrapper(configuration: configuration)
        case .multiple(let document):
            return try document.fileWrapper(configuration: configuration)
        }
    }
    
    // Добавляем вычисляемые свойства
    var contentType: UTType {
        switch self {
        case .single(let document):
            return document.contentType
        case .multiple(let document):
            return document.contentType
        }
    }
    
    var fileName: String {
        switch self {
        case .single(let document):
            return document.fileName
        case .multiple(let document):
            return document.fileName
        }
    }
}

// View для экспорта/импорта заметок
struct NoteExportImportView: View {
    @Environment(\.modelContext) private var context
    @Query private var notes: [Note]
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var selectedNote: Note?
    @State private var exportSingleNote = false
    @State private var exportDocument: ExportDocumentWrapper?
    
    var body: some View {
        List {
            Section("Import/Export") {
                Button("Export All Notes") {
                    if let _ = NoteExportImport.shared.exportAllNotes(notes) {
                        exportDocument = .multiple(NotesDocument(notes: notes))
                        isExporting = true
                        exportSingleNote = false
                        selectedNote = nil
                    }
                }
                
                Button("Import Notes") {
                    isImporting = true
                }
            }
            
            if !notes.isEmpty {
                Section("Export Individual Notes") {
                    ForEach(notes) { note in
                        Button(note.title) {
                            if let _ = NoteExportImport.shared.exportNote(note) {
                                selectedNote = note
                                exportDocument = .single(NoteDocument(note: note))
                                exportSingleNote = true
                                isExporting = true
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Import/Export")
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: exportSingleNote ? .youNote : .youNotes,
            defaultFilename: exportSingleNote && selectedNote != nil ? 
                "\(selectedNote!.title).ynote" : 
                "YouNotes_\(Date().formatted(.dateTime.year().month().day())).ynotes"
        ) { result in
            switch result {
            case .success(let url):
                print("Exported to \(url)")
            case .failure(let error):
                print("Export failed: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.youNote, .youNotes],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    if url.pathExtension == "ynote" {
                        if let _ = NoteExportImport.shared.importNote(from: url, into: context) {
                            print("Note imported successfully")
                        }
                    } else if url.pathExtension == "ynotes" {
                        let importedNotes = NoteExportImport.shared.importAllNotes(from: url, into: context)
                        print("\(importedNotes.count) notes imported successfully")
                    }
                }
            case .failure(let error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
    }
}
