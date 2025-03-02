import SwiftUI
import SwiftData

@Model
final class Note {
    var title: String
    var content: String
    var tags: [String]
    var category: String
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    var color: String // Используем строковое значение для совместимости с SwiftData
    
    init(title: String, content: String, tags: [String] = [], category: String = "Uncategorized", isFavorite: Bool = false, color: String = "blue") {
        self.title = title
        self.content = content
        self.tags = tags
        self.category = category
        self.isFavorite = isFavorite
        self.createdAt = Date()
        self.updatedAt = Date()
        self.color = color
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fontName") private var fontName: String = "SF Pro"
    @AppStorage("fontSize") private var fontSize: Double = 16.0
    @AppStorage("accentColor") private var accentColor: String = "blue"
    @AppStorage("defaultCategory") private var defaultCategory: String = "Uncategorized"
    
    @Query private var notes: [Note]
    
    @State private var searchText = ""
    @State private var selectedNote: Note?
    @State private var selectedCategory: String?
    @State private var selectedTag: String?
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var isShowingSettings = false
    @State private var isPresentingQuickSearch = false
    @State private var isEditorInFullScreen = false
    
    // Вычисляемые свойства
    private var categories: [String] {
        var cats = Set(notes.map { $0.category })
        cats.insert("All Notes")
        cats.insert("Favorites")
        return cats.sorted()
    }
    
    private var allTags: [String] {
        var tags = Set<String>()
        for note in notes {
            for tag in note.tags {
                tags.insert(tag)
            }
        }
        return tags.sorted()
    }
    
    private var filteredNotes: [Note] {
        var filtered = notes
        
        // Фильтр по категории
        if let selectedCategory = selectedCategory {
            if selectedCategory == "All Notes" {
                // Показываем все заметки
            } else if selectedCategory == "Favorites" {
                filtered = filtered.filter { $0.isFavorite }
            } else {
                filtered = filtered.filter { $0.category == selectedCategory }
            }
        }
        
        // Фильтр по тегу
        if let selectedTag = selectedTag {
            filtered = filtered.filter { $0.tags.contains(selectedTag) }
        }
        
        // Фильтр по поиску
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Сортировка по дате обновления (сначала новые)
        return filtered.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    private var sidebarLibrarySection: some View {
        Section("Library") {
            Label("All Notes", systemImage: "tray.full")
                .tag("All Notes")
            
            Label("Favorites", systemImage: "star")
                .tag("Favorites")
        }
    }
    
    private var sidebarCategoriesSection: some View {
        Section("Categories") {
            ForEach(categories.filter { $0 != "All Notes" && $0 != "Favorites" }, id: \.self) { category in
                Label(category, systemImage: "folder")
                    .tag(category)
                    .contextMenu {
                        Button("Rename", action: {
                            // В будущей версии
                        })
                        Button("Delete", role: .destructive, action: {
                            // В будущей версии
                        })
                    }
            }
            
            Button(action: { showingAddCategory = true }) {
                Label("Add Category", systemImage: "plus")
            }
        }
    }
    
    private var sidebarTagsSection: some View {
        Group {
            if !allTags.isEmpty {
                Section("Tags") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(allTags, id: \.self) { tag in
                                TagView(tag: tag, isSelected: selectedTag == tag)
                                    .onTapGesture {
                                        selectedTag = selectedTag == tag ? nil : tag
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
        }
    }
    
    private var sidebarView: some View {
        List(selection: $selectedCategory) {
            sidebarLibrarySection
            sidebarCategoriesSection
            sidebarTagsSection
        }
        .searchable(text: $searchText, prompt: "Search notes...")
        .navigationTitle("YouNote")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { createNote() }) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n")
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: { isShowingSettings = true }) {
                    Label("Settings", systemImage: "gear")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: { isPresentingQuickSearch = true }) {
                    Label("Quick Search", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }
    
    private var notesListView: some View {
        List(selection: $selectedNote) {
            if filteredNotes.isEmpty {
                ContentUnavailableView {
                    Label("No Notes Found", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Try changing your search or create a new note.")
                } actions: {
                    Button("Create Note") {
                        createNote()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ForEach(filteredNotes) { note in
                    NoteRow(note: note)
                        .tag(note)
                        .contextMenu {
                            Button {
                                note.isFavorite.toggle()
                            } label: {
                                Label(note.isFavorite ? "Remove from Favorites" : "Add to Favorites", 
                                      systemImage: note.isFavorite ? "star.slash" : "star")
                            }
                            
                            Menu("Move to") {
                                ForEach(categories.filter { $0 != "All Notes" && $0 != "Favorites" }, id: \.self) { category in
                                    Button(category) {
                                        note.category = category
                                    }
                                }
                            }
                            
                            Divider()
                            
                            Button("Delete", role: .destructive) {
                                context.delete(note)
                                if selectedNote == note {
                                    selectedNote = nil
                                }
                            }
                        }
                }
            }
        }
        .overlay {
            if notes.isEmpty && searchText.isEmpty && selectedTag == nil && (selectedCategory == nil || selectedCategory == "All Notes") {
                ContentUnavailableView {
                    Label("No Notes", systemImage: "note.text")
                } description: {
                    Text("Create your first note to get started")
                } actions: {
                    Button("Create Note") {
                        createNote()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Button {
                        if let selectedCategory = selectedCategory, selectedCategory != "All Notes" && selectedCategory != "Favorites" {
                            createNote(category: selectedCategory)
                        } else {
                            createNote()
                        }
                    } label: {
                        Label("New Note", systemImage: "square.and.pencil")
                    }
                    
                    Button("Import Note") {
                        // Будет реализовано в будущих версиях
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
    }
    
    private var detailView: some View {
        Group {
            if let selectedNote = selectedNote {
                VStack(spacing: 0) {
                    if !isEditorInFullScreen {
                        // Toolbar
                        HStack {
                            TextField("Title", text: Binding(
                                get: { selectedNote.title },
                                set: { selectedNote.title = $0 }
                            ))
                            .font(.title2.bold())
                            .padding(.horizontal)
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                // Кнопка добавления тега
                                Menu {
                                    Button("Add New Tag...") {
                                        // В будущей версии
                                    }
                                    
                                    if !allTags.isEmpty {
                                        Divider()
                                        
                                        ForEach(allTags, id: \.self) { tag in
                                            Button(tag) {
                                                if !selectedNote.tags.contains(tag) {
                                                    selectedNote.tags.append(tag)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Add Tag", systemImage: "tag")
                                }
                                
                                // Кнопка избранного
                                Button {
                                    selectedNote.isFavorite.toggle()
                                } label: {
                                    Image(systemName: selectedNote.isFavorite ? "star.fill" : "star")
                                        .foregroundColor(selectedNote.isFavorite ? .yellow : .gray)
                                }
                                
                                // Кнопка выбора цвета
                                Menu {
                                    Button("Blue") { selectedNote.color = "blue" }
                                    Button("Green") { selectedNote.color = "green" }
                                    Button("Red") { selectedNote.color = "red" }
                                    Button("Yellow") { selectedNote.color = "yellow" }
                                    Button("Purple") { selectedNote.color = "purple" }
                                } label: {
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(Color.colorFromString(selectedNote.color))
                                }
                                
                                // Кнопка полноэкранного режима
                                Button {
                                    isEditorInFullScreen.toggle()
                                } label: {
                                    Image(systemName: isEditorInFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                        .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
                        
                        // Теги
                        if !selectedNote.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(selectedNote.tags, id: \.self) { tag in
                                        TagView(tag: tag, isSelected: false)
                                            .contextMenu {
                                                Button("Remove", role: .destructive) {
                                                    selectedNote.tags.removeAll { $0 == tag }
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // Редактор заметки
                    RichTextEditor(note: selectedNote)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .overlay(alignment: .topTrailing) {
                    if isEditorInFullScreen {
                        Button {
                            isEditorInFullScreen.toggle()
                        } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .padding(8)
                                .background(colorScheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No Note Selected", systemImage: "square.and.pencil")
                } description: {
                    Text("Select a note from the list or create a new one")
                }
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            sidebarView
        } content: {
            notesListView
        } detail: {
            detailView
        }
        .sheet(isPresented: $showingAddCategory) {
            VStack(spacing: 20) {
                Text("New Category")
                    .font(.headline)
                
                TextField("Category Name", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                HStack {
                    Button("Cancel") {
                        newCategoryName = ""
                        showingAddCategory = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Create") {
                        if !newCategoryName.isEmpty {
                            // В текущей версии просто выбираем категорию,
                            // в будущем можно будет добавить метаданные категорий
                            selectedCategory = newCategoryName
                            newCategoryName = ""
                            showingAddCategory = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newCategoryName.isEmpty)
                }
            }
            .padding()
            .frame(width: 300, height: 200)
            .presentationDetents([.height(200)])
        }
        .sheet(isPresented: $isPresentingQuickSearch) {
            QuickSearchView(notes: notes, onNoteSelected: { note in
                selectedNote = note
                isPresentingQuickSearch = false
            })
        }
        .onAppear {
            if notes.isEmpty {
                createWelcomeNote()
            }
        }
    }
    
    private func createNote(category: String? = nil) {
        let newNote = Note(
            title: "Untitled Note",
            content: "",
            category: category ?? selectedCategory ?? defaultCategory
        )
        context.insert(newNote)
        selectedNote = newNote
    }
    
    private func createWelcomeNote() {
        let welcomeNote = Note(
            title: "Добро пожаловать в YouNote!",
            content: """
            ## Это ваша первая заметка
            
            YouNote - это современное приложение для заметок с поддержкой:
            
            - **Категорий** для организации заметок
            - **Тегов** для удобного поиска
            - **Редактора** с форматированием текста
            - **Импорта и экспорта** заметок
            
            Попробуйте создать свою первую заметку, нажав на кнопку "+" в панели инструментов!
            """,
            tags: ["welcome", "tutorial"],
            category: "Getting Started",
            isFavorite: true,
            color: "green"
        )
        context.insert(welcomeNote)
    }
}

struct NoteRow: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.title)
                    .font(.headline)
                    .foregroundStyle(note.isFavorite ? .yellow : .primary)
                
                Spacer()
                
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Text(note.content)
                .lineLimit(2)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if !note.tags.isEmpty {
                HStack {
                    ForEach(note.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.2))
                            }
                    }
                    
                    if note.tags.count > 3 {
                        Text("+\(note.tags.count - 3)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(note.color).opacity(0.1))
                .padding(4)
        )
    }
}

struct TagView: View {
    let tag: String
    let isSelected: Bool
    
    var body: some View {
        Text(tag)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
    }
}

extension Color {
    static func colorFromString(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .blue
        }
    }
}

struct QuickSearchView: View {
    let notes: [Note]
    let onNoteSelected: (Note) -> Void
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return notes
        } else {
            return notes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack {
            TextField("Search...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            List(filteredNotes) { note in
                Button(action: {
                    onNoteSelected(note)
                }) {
                    VStack(alignment: .leading) {
                        Text(note.title)
                            .font(.headline)
                        Text(note.content.prefix(50))
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
                .buttonStyle(.plain)
            }
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .frame(width: 400, height: 400)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true, isAutosaveEnabled: true)
}
