import SwiftUI
import SwiftData
import AppKit

// Представление-обертка для NSTextView
struct NSTextViewWrapper: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRanges: [NSValue]
    var font: NSFont
    var onTextChange: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = CustomTextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.allowsUndo = true
        textView.isRichText = false // Используем только plain text для совместимости со SwiftData
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CustomTextView else { return }
        
        // Обновляем текст только если он изменился извне
        if textView.string != text {
            textView.string = text
        }
        
        // Устанавливаем выделение, если нужно
        if !selectedRanges.isEmpty && textView.selectedRanges != selectedRanges {
            textView.selectedRanges = selectedRanges
        }
        
        textView.font = font
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRanges: $selectedRanges, onTextChange: onTextChange)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var selectedRanges: Binding<[NSValue]>
        var onTextChange: () -> Void
        
        init(text: Binding<String>, selectedRanges: Binding<[NSValue]>, onTextChange: @escaping () -> Void) {
            self.text = text
            self.selectedRanges = selectedRanges
            self.onTextChange = onTextChange
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            selectedRanges.wrappedValue = textView.selectedRanges
            onTextChange()
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            selectedRanges.wrappedValue = textView.selectedRanges
        }
    }
    
    // Кастомный NSTextView для дополнительного функционала
    class CustomTextView: NSTextView {
        // Здесь можно переопределить дополнительные методы
    }
}

struct RichTextEditor: View {
    @Bindable var note: Note
    @State private var selectedRanges: [NSValue] = []
    @FocusState private var isEditorFocused: Bool
    @State private var showingInsertImage = false
    @State private var showingLinkEditor = false
    @State private var linkURL = ""
    @State private var linkTitle = ""
    @AppStorage("fontName") private var fontName: String = "SF Pro"
    @AppStorage("fontSize") private var fontSize: Double = 16.0
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var font: NSFont {
        NSFont(name: fontName, size: CGFloat(fontSize)) ?? NSFont.systemFont(ofSize: CGFloat(fontSize))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Панель форматирования
            HStack(spacing: 12) {
                FormatButton(iconName: "bold", action: applyBold)
                FormatButton(iconName: "italic", action: applyItalic)
                FormatButton(iconName: "underline", action: applyUnderline)
                
                Divider()
                    .frame(height: 20)
                
                Menu {
                    Button("Heading 1") { applyHeading(level: 1) }
                    Button("Heading 2") { applyHeading(level: 2) }
                    Button("Heading 3") { applyHeading(level: 3) }
                    Button("Body") { applyNormalText() }
                } label: {
                    Image(systemName: "textformat.size")
                        .frame(width: 30, height: 30)
                }
                
                Divider()
                    .frame(height: 20)
                
                FormatButton(iconName: "list.bullet", action: applyBulletList)
                FormatButton(iconName: "list.number", action: applyNumberedList)
                FormatButton(iconName: "checkmark.square", action: applyCheckList)
                
                Divider()
                    .frame(height: 20)
                
                Button(action: { showingInsertImage = true }) {
                    Image(systemName: "photo")
                        .frame(width: 30, height: 30)
                }
                
                Button(action: { showingLinkEditor = true }) {
                    Image(systemName: "link")
                        .frame(width: 30, height: 30)
                }
                
                Spacer()
                
                Button(action: sharePlainText) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(colorScheme == .dark ? Color(NSColor.darkGray) : Color(NSColor.lightGray).opacity(0.3))
            
            // Редактор текста на базе NSTextView
            NSTextViewWrapper(
                text: $note.content,
                selectedRanges: $selectedRanges,
                font: font,
                onTextChange: updateNote
            )
            .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingInsertImage) {
            ImagePickerView(onImageSelected: insertImage)
        }
        .sheet(isPresented: $showingLinkEditor) {
            LinkEditorView(url: $linkURL, title: $linkTitle, onInsert: insertLink)
        }
    }
    
    private func updateNote() {
        note.updatedAt = Date()
    }
    
    // Получение текущего выделения
    private var currentSelection: NSRange? {
        guard let range = selectedRanges.first?.rangeValue else { return nil }
        return range
    }
    
    // Методы форматирования
    private func applyBold() {
        wrapSelectedText(with: "**")
    }
    
    private func applyItalic() {
        wrapSelectedText(with: "*")
    }
    
    private func applyUnderline() {
        wrapSelectedText(with: "__")
    }
    
    private func applyHeading(level: Int) {
        let prefix = String(repeating: "#", count: level) + " "
        prefixLine(with: prefix)
    }
    
    private func applyNormalText() {
        removePrefixFromLine(matching: "^#+\\s")
    }
    
    private func applyBulletList() {
        prefixLine(with: "- ")
    }
    
    private func applyNumberedList() {
        prefixLine(with: "1. ")
    }
    
    private func applyCheckList() {
        prefixLine(with: "- [ ] ")
    }
    
    private func insertImage(_ imageName: String) {
        let imageMarkdown = "![image](\(imageName))"
        insertTextAtCursor(imageMarkdown)
    }
    
    private func insertLink() {
        let linkMarkdown = "[\(linkTitle)](\(linkURL))"
        insertTextAtCursor(linkMarkdown)
        linkURL = ""
        linkTitle = ""
    }
    
    private func sharePlainText() {
        let sharingItems: [Any] = [note.title, note.content]
        let sharingService = NSSharingServicePicker(items: sharingItems)
        
        if let window = NSApplication.shared.windows.first {
            sharingService.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
        }
    }
    
    // Вспомогательные методы для форматирования текста
    private func insertTextAtCursor(_ text: String) {
        if let range = currentSelection {
            let content = note.content as NSString
            let newContent = content.replacingCharacters(in: range, with: text)
            note.content = newContent
            
            // Устанавливаем курсор в конец вставленного текста
            let newPosition = range.location + text.count
            let newRange = NSRange(location: newPosition, length: 0)
            selectedRanges = [NSValue(range: newRange)]
        } else {
            // Курсор в конце текста
            note.content.append(text)
        }
        
        updateNote()
    }
    
    private func wrapSelectedText(with wrapper: String) {
        if let range = currentSelection, range.length > 0 {
            let content = note.content as NSString
            let selectedText = content.substring(with: range)
            let wrappedText = wrapper + selectedText + wrapper
            let newContent = content.replacingCharacters(in: range, with: wrappedText)
            note.content = newContent
            
            // Сохраняем выделение с учетом добавленной обертки
            let newRange = NSRange(location: range.location, length: wrappedText.count)
            selectedRanges = [NSValue(range: newRange)]
        } else {
            // Текст не выделен, вставляем обертку и помещаем курсор между тегами
            let cursorPosition = currentSelection?.location ?? note.content.count
            let content = note.content as NSString
            let newContent = content.replacingCharacters(
                in: NSRange(location: cursorPosition, length: 0),
                with: wrapper + wrapper
            )
            note.content = newContent
            
            // Помещаем курсор между тегами
            let newPosition = cursorPosition + wrapper.count
            selectedRanges = [NSValue(range: NSRange(location: newPosition, length: 0))]
        }
        
        updateNote()
    }
    
    private func prefixLine(with prefix: String) {
        guard !note.content.isEmpty else {
            note.content = prefix
            return
        }
        
        let cursorPosition = currentSelection?.location ?? 0
        let content = note.content as NSString
        
        // Находим начало и конец текущей строки
        let lineStart = content.substring(to: cursorPosition).lastIndex(of: "\n")
            .map { content.substring(to: $0 + 1).count } ?? 0
        
        let lineEnd = content.substring(from: cursorPosition).firstIndex(of: "\n")
            .map { cursorPosition + $0 } ?? content.length
        
        let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
        let line = content.substring(with: lineRange)
        
        // Проверяем, начинается ли строка уже с префикса
        if !line.hasPrefix(prefix) {
            let newContent = content.replacingCharacters(
                in: lineRange,
                with: prefix + line
            )
            note.content = newContent
            
            // Обновляем позицию курсора
            let newCursorPosition = cursorPosition + prefix.count
            selectedRanges = [NSValue(range: NSRange(location: newCursorPosition, length: 0))]
        }
        
        updateNote()
    }
    
    private func removePrefixFromLine(matching regex: String) {
        guard !note.content.isEmpty else { return }
        
        let cursorPosition = currentSelection?.location ?? 0
        let content = note.content as NSString
        
        // Находим начало и конец текущей строки
        let lineStart = content.substring(to: cursorPosition).lastIndex(of: "\n")
            .map { content.substring(to: $0 + 1).count } ?? 0
        
        let lineEnd = content.substring(from: cursorPosition).firstIndex(of: "\n")
            .map { cursorPosition + $0 } ?? content.length
        
        let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
        let line = content.substring(with: lineRange)
        
        // Используем регулярное выражение для поиска и удаления префикса
        if let regex = try? NSRegularExpression(pattern: regex, options: []),
           let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
            
            let prefixLength = match.range.length
            let newLine = line.substring(from: prefixLength)
            
            let newContent = content.replacingCharacters(
                in: lineRange,
                with: newLine
            )
            note.content = newContent
            
            // Обновляем позицию курсора
            let newCursorPosition = max(cursorPosition - prefixLength, lineStart)
            selectedRanges = [NSValue(range: NSRange(location: newCursorPosition, length: 0))]
            
            updateNote()
        }
    }
}

struct FormatButton: View {
    let iconName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .frame(width: 30, height: 30)
        }
    }
}

struct ImagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onImageSelected: (String) -> Void
    
    @State private var selectedImageName = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Эта функция будет реализована в будущих версиях")
                    .padding()
                
                TextField("Имя файла изображения", text: $selectedImageName)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                Button("Вставить") {
                    if !selectedImageName.isEmpty {
                        onImageSelected(selectedImageName)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedImageName.isEmpty)
            }
            .padding()
            .frame(width: 400, height: 300)
            .navigationTitle("Выбор изображения")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LinkEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var url: String
    @Binding var title: String
    let onInsert: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Link Details") {
                    TextField("URL", text: $url)
                    TextField("Title", text: $title)
                }
            }
            .navigationTitle("Insert Link")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") {
                        onInsert()
                        dismiss()
                    }
                    .disabled(url.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 200)
    }
}

#Preview {
    RichTextEditor(note: Note(title: "Test Note", content: "Test content"))
}
