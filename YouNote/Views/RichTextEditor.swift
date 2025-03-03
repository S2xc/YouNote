import SwiftUI
import SwiftData
import AppKit

// Обертка для NSTextView, которая позволяет форматировать текст
struct RichTextViewRepresentable: NSViewRepresentable {
    @Binding var text: NSAttributedString
    let textDidChange: (NSAttributedString) -> Void
    @Binding var selectedRanges: [NSValue]
    let onPasteImage: ((NSImage) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 5, height: 5)
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.font = NSFont.systemFont(ofSize: 14)
        
        // Устанавливаем начальное выделение, если его нет
        if selectedRanges.isEmpty {
            let initialRange = NSRange(location: 0, length: 0)
            textView.selectedRanges = [NSValue(range: initialRange)]
            context.coordinator.selectedRanges = textView.selectedRanges
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Обновляем текст, только если он изменился
        if textView.attributedString() != text {
            textView.textStorage?.setAttributedString(text)
        }
        
        // Устанавливаем атрибуты для ввода текста
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.white
        ]
        
        // Обновляем выделение, если оно изменилось и не пустое
        if !selectedRanges.isEmpty && textView.selectedRanges != selectedRanges {
            textView.selectedRanges = selectedRanges
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRanges: $selectedRanges, textDidChange: textDidChange, onPasteImage: onPasteImage)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: NSAttributedString
        @Binding var selectedRanges: [NSValue]
        let textDidChange: (NSAttributedString) -> Void
        var onPasteImage: ((NSImage) -> Void)?
        
        init(text: Binding<NSAttributedString>, selectedRanges: Binding<[NSValue]>, textDidChange: @escaping (NSAttributedString) -> Void, onPasteImage: ((NSImage) -> Void)? = nil) {
            self._text = text
            self._selectedRanges = selectedRanges
            self.textDidChange = textDidChange
            self.onPasteImage = onPasteImage
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.text = textView.attributedString()
            self.textDidChange(textView.attributedString())
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Проверяем, что массив выделения не пуст
            if !textView.selectedRanges.isEmpty {
                self.selectedRanges = textView.selectedRanges
            } else {
                // Если пуст, создаем фиктивное выделение в начале текста
                let initialRange = NSRange(location: 0, length: 0)
                self.selectedRanges = [NSValue(range: initialRange)]
            }
        }
        
        // Обработка кликов для переключения чекбоксов
        func textView(_ textView: NSTextView, clickedOnCell cell: NSCell, in rect: NSRect, at charIndex: Int) -> Bool {
            return false
        }
        
        func textView(_ textView: NSTextView, mouseDown event: NSEvent, at charIndex: Int, contentView: NSTextView) -> Bool {
            guard let textStorage = textView.textStorage else { return false }
            
            // Определяем, на какой строке произошло нажатие
            let string = textStorage.string
            let nsString = string as NSString
            
            // Находим начало текущей строки
            var lineStart = 0
            var lineEnd = 0
            nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: nil, for: NSRange(location: charIndex, length: 0))
            
            // Проверяем, есть ли клик в начале строки, где мог бы быть чекбокс
            if charIndex < lineStart + 2 && lineStart + 2 <= textStorage.length {
                let checkboxRange = NSRange(location: lineStart, length: 1)
                if checkboxRange.length <= 0 || checkboxRange.location + checkboxRange.length > textStorage.length {
                    return false
                }
                
                let checkboxChar = nsString.substring(with: checkboxRange)
                
                // Проверяем, является ли символ чекбоксом
                if checkboxChar == "☐" {
                    // Заменяем пустой чекбокс на чекбокс с галочкой
                    let attributes = textStorage.attributes(at: lineStart, effectiveRange: nil)
                    let newCheckbox = NSAttributedString(string: "☑", attributes: attributes)
                    textStorage.replaceCharacters(in: checkboxRange, with: newCheckbox)
                    self.text = textView.attributedString()
                    self.textDidChange(textView.attributedString())
                    return true
                } else if checkboxChar == "☑" {
                    // Заменяем чекбокс с галочкой на пустой чекбокс
                    let attributes = textStorage.attributes(at: lineStart, effectiveRange: nil)
                    let newCheckbox = NSAttributedString(string: "☐", attributes: attributes)
                    textStorage.replaceCharacters(in: checkboxRange, with: newCheckbox)
                    self.text = textView.attributedString()
                    self.textDidChange(textView.attributedString())
                    return true
                }
            }
            
            return false
        }
        
        // Обработка вставки изображений
        func textView(_ textView: NSTextView, shouldChangeTextInRanges affectedRanges: [NSValue], replacementStrings: [String]?) -> Bool {
            // Проверяем, не вставляется ли изображение
            if let event = NSApp.currentEvent, event.type == .keyDown,
               event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                
                // Проверяем буфер обмена на наличие изображения
                let pasteboard = NSPasteboard.general
                if let image = NSImage(pasteboard: pasteboard) {
                    // Если нашли изображение, вызываем обработчик
                    if let onPasteImage = onPasteImage {
                        onPasteImage(image)
                        return false // Отменяем стандартную вставку
                    }
                }
            }
            
            return true // Разрешаем стандартную вставку для других случаев
        }
    }
}

struct RichTextEditor: View {
    @Bindable var note: Note
    @State private var attributedText: NSAttributedString = NSAttributedString(string: "")
    // Инициализируем с фиктивным выделением в начале текста
    @State private var selectedRanges: [NSValue] = [NSValue(range: NSRange(location: 0, length: 0))]
    
    @State private var showingInsertImage = false
    @State private var showingLinkEditor = false
    @State private var linkURL = ""
    @State private var linkTitle = ""
    
    @AppStorage("fontName") private var fontName: String = "SF Pro"
    @AppStorage("fontSize") private var fontSize: Double = 16.0
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Функция для создания уникального имени файла
    private func generateUniqueImageName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let randomString = UUID().uuidString.prefix(8)
        return "image_\(dateString)_\(randomString)"
    }
    
    // Директория для хранения изображений
    private func getImagesDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let imagesDirectory = documentsDirectory.appendingPathComponent("YouNoteImages", isDirectory: true)
        
        // Создаем директорию, если она не существует
        if !FileManager.default.fileExists(atPath: imagesDirectory.path) {
            try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
        
        return imagesDirectory
    }
    
    // Функции для работы с атрибутированным текстом
    private func updateNoteContent() {
        // Сохраняем форматированный текст в contentData
        if let data = try? attributedText.data(from: NSRange(location: 0, length: attributedText.length),
                                        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) {
            note.contentData = data
        }
        
        // Обновляем обычный текст для поиска и т.д.
        note.content = attributedText.string
        note.updatedAt = Date()
    }
    
    private func makeTextBold() {
        guard !selectedRanges.isEmpty else { return }
        
        let fontManager = NSFontManager.shared
        let textStorage = NSTextStorage(attributedString: attributedText)
        
        for range in selectedRanges.map({ $0.rangeValue }) where range.length > 0 {
            // Проверяем, весь ли текст в диапазоне уже жирный
            var allBold = true
            var anyFont = false
            
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, subrange, stop in
                if let font = value as? NSFont {
                    anyFont = true
                    if !fontManager.traits(of: font).contains(.boldFontMask) {
                        allBold = false
                        stop.pointee = true
                    }
                } else {
                    allBold = false
                    stop.pointee = true
                }
            }
            
            // Если весь текст уже жирный, снимаем жирность, иначе делаем жирным
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, subrange, stop in
                if let oldFont = value as? NSFont {
                    let traits = fontManager.traits(of: oldFont)
                    var newFont: NSFont
                    
                    if allBold && anyFont {
                        // Убираем жирность, сохраняя другие атрибуты (например, курсив)
                        var newTraits = traits
                        newTraits.remove(.boldFontMask)
                        
                        if newTraits.contains(.italicFontMask) {
                            // Если у нас остается курсив
                            newFont = fontManager.convert(NSFont.systemFont(ofSize: oldFont.pointSize), toHaveTrait: .italicFontMask)
                        } else {
                            // Если не остается других атрибутов
                            newFont = NSFont.systemFont(ofSize: oldFont.pointSize)
                        }
                    } else {
                        // Делаем жирным, сохраняя предыдущие атрибуты
                        newFont = fontManager.convert(oldFont, toHaveTrait: .boldFontMask)
                    }
                    
                    textStorage.addAttribute(.font, value: newFont, range: subrange)
                } else {
                    // Если нет шрифта, добавляем жирный системный шрифт
                    let newFont = fontManager.convert(NSFont.systemFont(ofSize: CGFloat(fontSize)), toHaveTrait: .boldFontMask)
                    textStorage.addAttribute(.font, value: newFont, range: subrange)
                }
            }
        }
        
        attributedText = textStorage
        updateNoteContent()
    }
    
    private func makeTextItalic() {
        guard !selectedRanges.isEmpty else { return }
        
        let fontManager = NSFontManager.shared
        let textStorage = NSTextStorage(attributedString: attributedText)
        
        for range in selectedRanges.map({ $0.rangeValue }) where range.length > 0 {
            // Проверяем, весь ли текст в диапазоне уже курсивный
            var allItalic = true
            var anyFont = false
            
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, subrange, stop in
                if let font = value as? NSFont {
                    anyFont = true
                    if !fontManager.traits(of: font).contains(.italicFontMask) {
                        allItalic = false
                        stop.pointee = true
                    }
                } else {
                    allItalic = false
                    stop.pointee = true
                }
            }
            
            // Если весь текст уже курсивный, снимаем курсив, иначе делаем курсивным
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, subrange, stop in
                if let oldFont = value as? NSFont {
                    let traits = fontManager.traits(of: oldFont)
                    var newFont: NSFont
                    
                    if allItalic && anyFont {
                        // Убираем курсив, сохраняя другие атрибуты (например, жирность)
                        var newTraits = traits
                        newTraits.remove(.italicFontMask)
                        
                        if newTraits.contains(.boldFontMask) {
                            // Если у нас остается жирность
                            newFont = fontManager.convert(NSFont.systemFont(ofSize: oldFont.pointSize), toHaveTrait: .boldFontMask)
                        } else {
                            // Если не остается других атрибутов
                            newFont = NSFont.systemFont(ofSize: oldFont.pointSize)
                        }
                    } else {
                        // Делаем курсивным, сохраняя предыдущие атрибуты
                        newFont = fontManager.convert(oldFont, toHaveTrait: .italicFontMask)
                    }
                    
                    textStorage.addAttribute(.font, value: newFont, range: subrange)
                } else {
                    // Если нет шрифта, добавляем курсивный системный шрифт
                    let newFont = fontManager.convert(NSFont.systemFont(ofSize: CGFloat(fontSize)), toHaveTrait: .italicFontMask)
                    textStorage.addAttribute(.font, value: newFont, range: subrange)
                }
            }
        }
        
        attributedText = textStorage
        updateNoteContent()
    }
    
    private func makeTextUnderlined() {
        guard !selectedRanges.isEmpty else { return }
        
        let textStorage = NSTextStorage(attributedString: attributedText)
        
        for range in selectedRanges.map({ $0.rangeValue }) where range.length > 0 {
            // Проверяем, весь ли текст в диапазоне уже подчеркнут
            var allUnderlined = true
            var anyUnderline = false
            
            textStorage.enumerateAttribute(.underlineStyle, in: range, options: []) { value, subrange, stop in
                if let style = value as? Int, style != 0 {
                    anyUnderline = true
                } else {
                    allUnderlined = false
                    stop.pointee = true
                }
            }
            
            // Если весь текст уже подчеркнут, снимаем подчеркивание, иначе подчеркиваем
            if allUnderlined && anyUnderline {
                textStorage.removeAttribute(.underlineStyle, range: range)
            } else {
                textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
        
        attributedText = textStorage
        updateNoteContent()
    }
    
    private func makeHeading(level: Int) {
        guard !selectedRanges.isEmpty else { return }
        
        let textStorage = NSTextStorage(attributedString: attributedText)
        let fontManager = NSFontManager.shared
        
        for rangeValue in selectedRanges where rangeValue.rangeValue.length > 0 {
            let range = rangeValue.rangeValue
            
            // Определяем размер шрифта для заголовка
            var size: CGFloat
            switch level {
            case 1: size = 24.0
            case 2: size = 20.0
            case 3: size = 18.0
            default: size = CGFloat(fontSize)
            }
            
            // Проверяем, является ли текст уже заголовком нужного уровня
            var isAlreadyHeading = true
            
            textStorage.enumerateAttribute(.font, in: range, options: []) { value, subrange, stop in
                if let font = value as? NSFont {
                    // Проверяем размер шрифта и жирность
                    if font.pointSize != size || !fontManager.traits(of: font).contains(.boldFontMask) {
                        isAlreadyHeading = false
                        stop.pointee = true
                    }
                } else {
                    isAlreadyHeading = false
                    stop.pointee = true
                }
            }
            
            if isAlreadyHeading {
                // Если текст уже является заголовком такого уровня, сбрасываем к обычному тексту
                let normalFont = NSFont.systemFont(ofSize: CGFloat(fontSize))
                textStorage.addAttribute(.font, value: normalFont, range: range)
            } else {
                // В противном случае делаем заголовком
                let font = NSFont.boldSystemFont(ofSize: size)
                textStorage.addAttribute(.font, value: font, range: range)
            }
        }
        
        attributedText = textStorage
        updateNoteContent()
    }
    
    private func insertBulletedList() {
        guard !selectedRanges.isEmpty, let currentRange = selectedRanges.first?.rangeValue else { return }
        let textStorage = NSTextStorage(attributedString: attributedText)
        
        // Получаем выделенный текст
        let selectedAttrText = textStorage.attributedSubstring(from: currentRange)
        let selectedText = selectedAttrText.string
        
        // Разбиваем текст на строки
        let lines = selectedText.components(separatedBy: .newlines)
        var resultText = NSMutableAttributedString()
        
        // Проверяем, является ли хотя бы одна строка уже маркированным списком
        var hasBulletList = false
        for line in lines {
            if line.hasPrefix("• ") {
                hasBulletList = true
                break
            }
        }
        
        var startOffset = 0
        
        for (index, line) in lines.enumerated() {
            let lineLength = line.count
            let lineRange = NSRange(location: startOffset, length: min(lineLength, selectedAttrText.length - startOffset))
            let lineAttrString = selectedAttrText.attributedSubstring(from: lineRange)
            
            // Сначала очищаем все маркеры списка, независимо от типа
            let cleanedText = cleanListMarkers(line)
            if hasBulletList {
                // Если это уже маркированный список и мы его удаляем, то просто используем очищенный текст
                let lineResultAttr = NSMutableAttributedString(string: cleanedText)
                
                // Копируем атрибуты из исходного текста, учитывая смещение из-за удаления маркеров
                let originalOffset = line.count - cleanedText.count
                for i in 0..<cleanedText.count {
                    let originalIndex = i + originalOffset
                    if originalIndex < lineAttrString.length {
                        let attrs = lineAttrString.attributes(at: originalIndex, effectiveRange: nil)
                        if i < lineResultAttr.length {
                            lineResultAttr.setAttributes(attrs, range: NSRange(location: i, length: 1))
                        }
                    }
                }
                resultText.append(lineResultAttr)
            } else {
                // Добавляем маркированный список, предварительно очистив от других маркеров
                if !cleanedText.isEmpty {
                    // Создаем атрибуты для маркера
                    let bulletAttr: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
                        .foregroundColor: NSColor.white
                    ]
                    
                    // Добавляем маркер
                    let bulletMarker = NSAttributedString(string: "• ", attributes: bulletAttr)
                    resultText.append(bulletMarker)
                    
                    // Создаем атрибутированную строку для текста с сохранением атрибутов оригинала
                    let textPart = NSMutableAttributedString()
                    
                    // Определяем смещение из-за удаления других маркеров
                    let originalOffset = line.count - cleanedText.count
                    
                    for i in 0..<cleanedText.count {
                        let originalIndex = min(i + originalOffset, lineAttrString.length - 1)
                        if originalIndex >= 0 {
                            let charAttr = lineAttrString.attributes(at: originalIndex, effectiveRange: nil)
                            let char = NSAttributedString(string: String(cleanedText[cleanedText.index(cleanedText.startIndex, offsetBy: i)]), attributes: charAttr)
                            textPart.append(char)
                        }
                    }
                    
                    resultText.append(textPart)
                } else {
                    // Для пустых строк сохраняем их как есть
                    resultText.append(lineAttrString)
                }
            }
            
            // Добавляем разрыв строки между строками (кроме последней)
            if index < lines.count - 1 {
                if startOffset + lineLength < selectedAttrText.length {
                    let newlineRange = NSRange(location: startOffset + lineLength, length: 1)
                    if newlineRange.location + newlineRange.length <= selectedAttrText.length {
                        let newlineAttr = selectedAttrText.attributedSubstring(from: newlineRange)
                        resultText.append(newlineAttr)
                    } else {
                        resultText.append(NSAttributedString(string: "\n", attributes: [
                            .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
                            .foregroundColor: NSColor.white
                        ]))
                    }
                } else {
                    resultText.append(NSAttributedString(string: "\n", attributes: [
                        .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
                        .foregroundColor: NSColor.white
                    ]))
                }
            }
            
            // Обновляем смещение для следующей строки
            startOffset += lineLength + (index < lines.count - 1 ? 1 : 0)
        }
        
        textStorage.replaceCharacters(in: currentRange, with: resultText)
        attributedText = textStorage
        updateNoteContent()
    }
    
    private func insertNumberedList() {
        guard !selectedRanges.isEmpty, let currentRange = selectedRanges.first?.rangeValue else { return }
        let textStorage = NSTextStorage(attributedString: attributedText)
        
        // Получаем выделенный текст
        let selectedAttrText = textStorage.attributedSubstring(from: currentRange)
        let selectedText = selectedAttrText.string
        
        // Разбиваем текст на строки
        let lines = selectedText.components(separatedBy: .newlines)
        var resultText = NSMutableAttributedString()
        
        // Проверяем, является ли хотя бы одна строка уже нумерованным списком
        var hasNumberedList = false
        for line in lines {
            if let range = line.range(of: #"^\d+\. "#, options: .regularExpression) {
                hasNumberedList = true
                break
            }
        }
        
        var startOffset = 0
        
        for (index, line) in lines.enumerated() {
            let lineLength = line.count
            let lineRange = NSRange(location: startOffset, length: min(lineLength, selectedAttrText.length - startOffset))
            let lineAttrString = selectedAttrText.attributedSubstring(from: lineRange)
            
            // Сначала очищаем все маркеры списка, независимо от типа
            let cleanedText = cleanListMarkers(line)
            
            if hasNumberedList {
                // Если это уже нумерованный список и мы его удаляем, то просто используем очищенный текст
                let lineResultAttr = NSMutableAttributedString(string: cleanedText)
                
                // Копируем атрибуты из исходного текста, учитывая смещение из-за удаления маркеров
                let originalOffset = line.count - cleanedText.count
                for i in 0..<cleanedText.count {
                    let originalIndex = i + originalOffset
                    if originalIndex < lineAttrString.length {
                        let attrs = lineAttrString.attributes(at: originalIndex, effectiveRange: nil)
                        if i < lineResultAttr.length {
                            lineResultAttr.setAttributes(attrs, range: NSRange(location: i, length: 1))
                        }
                    }
                }
                resultText.append(lineResultAttr)
            } else {
                // Добавляем нумерованный список, предварительно очистив от других маркеров
                if !cleanedText.isEmpty {
                    // Создаем атрибуты для маркера
                    let numberAttr: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
                        .foregroundColor: NSColor.white
                    ]
                    
                    // Добавляем номер
                    let numberMarker = NSAttributedString(string: "\(index + 1). ", attributes: numberAttr)
                    resultText.append(numberMarker)
                    
                    // Создаем атрибутированную строку для текста с сохранением атрибутов оригинала
                    let textPart = NSMutableAttributedString()
                    
                    // Определяем смещение из-за удаления других маркеров
                    let originalOffset = line.count - cleanedText.count
                    
                    for i in 0..<cleanedText.count {
                        let originalIndex = min(i + originalOffset, lineAttrString.length - 1)
                        if originalIndex >= 0 {
                            let charAttr = lineAttrString.attributes(at: originalIndex, effectiveRange: nil)
                            let char = NSAttributedString(string: String(cleanedText[cleanedText.index(cleanedText.startIndex, offsetBy: i)]), attributes: charAttr)
                            textPart.append(char)
                        }
                    }
                    
                    resultText.append(textPart)
                } else {
                    // Для пустых строк сохраняем их как есть
                    resultText.append(lineAttrString)
                }
            }
            
            // Добавляем разрыв строки между строками (кроме последней)
            if index < lines.count - 1 {
                if startOffset + lineLength < selectedAttrText.length {
                    let newlineRange = NSRange(location: startOffset + lineLength, length: 1)
                    if newlineRange.location + newlineRange.length <= selectedAttrText.length {
                        let newlineAttr = selectedAttrText.attributedSubstring(from: newlineRange)
                        resultText.append(newlineAttr)
                    } else {
                        resultText.append(NSAttributedString(string: "\n", attributes: [
                            .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
                            .foregroundColor: NSColor.white
                        ]))
                    }
                } else {
                    resultText.append(NSAttributedString(string: "\n", attributes: [
                        .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
                        .foregroundColor: NSColor.white
                    ]))
                }
            }
            
            // Обновляем смещение для следующей строки
            startOffset += lineLength + (index < lines.count - 1 ? 1 : 0)
        }
        
        textStorage.replaceCharacters(in: currentRange, with: resultText)
        attributedText = textStorage
        updateNoteContent()
    }
    
    private func insertChecklist() {
        guard !selectedRanges.isEmpty, let currentRange = selectedRanges.first?.rangeValue else { return }
        let textStorage = NSTextStorage(attributedString: attributedText)
        
        // Получаем выделенный текст
        let selectedAttrText = textStorage.attributedSubstring(from: currentRange)
        let selectedText = selectedAttrText.string
        
        // Разбиваем текст на строки
        let lines = selectedText.components(separatedBy: .newlines)
        var resultText = NSMutableAttributedString()
        
        // Проверяем, является ли хотя бы одна строка уже списком с чекбоксами
        var hasChecklist = false
        for line in lines {
            if line.hasPrefix("☐ ") || line.hasPrefix("☑ ") {
                hasChecklist = true
                break
            }
        }
        
        var startOffset = 0
        
        for (index, line) in lines.enumerated() {
            let lineLength = line.count
            let lineRange = NSRange(location: startOffset, length: min(lineLength, selectedAttrText.length - startOffset))
            let lineAttrString = selectedAttrText.attributedSubstring(from: lineRange)
            
            // Сначала очищаем все маркеры списка, независимо от типа
            let cleanedText = cleanListMarkers(line)
            
            if hasChecklist {
                // Если это уже чек-лист и мы его удаляем, то просто используем очищенный текст
                let lineResultAttr = NSMutableAttributedString(string: cleanedText)
                
                // Копируем атрибуты из исходного текста, учитывая смещение из-за удаления маркеров
                let originalOffset = line.count - cleanedText.count
                for i in 0..<cleanedText.count {
                    let originalIndex = i + originalOffset
                    if originalIndex < lineAttrString.length {
                        let attrs = lineAttrString.attributes(at: originalIndex, effectiveRange: nil)
                        if i < lineResultAttr.length {
                            lineResultAttr.setAttributes(attrs, range: NSRange(location: i, length: 1))
                        }
                    }
                }
                resultText.append(lineResultAttr)
            } else {
                // Добавляем чекбоксы, предварительно очистив от других маркеров
                if !cleanedText.isEmpty {
                    // Создаем чекбокс с особыми атрибутами для определения кликабельности
                    let checkboxAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
                        .foregroundColor: NSColor.white,
                        // Добавляем пользовательский атрибут для обозначения кликабельного чекбокса
                        NSAttributedString.Key("CheckboxMarker"): true
                    ]
                    
                    // Добавляем чекбокс
                    let checkboxMarker = NSAttributedString(string: "☐ ", attributes: checkboxAttributes)
                    resultText.append(checkboxMarker)
                    
                    // Создаем атрибутированную строку для текста с сохранением атрибутов оригинала
                    let textPart = NSMutableAttributedString()
                    
                    // Определяем смещение из-за удаления других маркеров
                    let originalOffset = line.count - cleanedText.count
                    
                    for i in 0..<cleanedText.count {
                        let originalIndex = min(i + originalOffset, lineAttrString.length - 1)
                        if originalIndex >= 0 && originalIndex < lineAttrString.length {
                            let charAttr = lineAttrString.attributes(at: originalIndex, effectiveRange: nil)
                            let char = NSAttributedString(string: String(cleanedText[cleanedText.index(cleanedText.startIndex, offsetBy: i)]), attributes: charAttr)
                            textPart.append(char)
                        } else {
                            // Если выходим за границы, используем дефолтные атрибуты
                            let char = NSAttributedString(string: String(cleanedText[cleanedText.index(cleanedText.startIndex, offsetBy: i)]), attributes: [
                                .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
                                .foregroundColor: NSColor.white
                            ])
                            textPart.append(char)
                        }
                    }
                    
                    resultText.append(textPart)
                } else {
                    // Для пустых строк сохраняем их как есть
                    resultText.append(lineAttrString)
                }
            }
            
            // Добавляем разрыв строки между строками (кроме последней)
            if index < lines.count - 1 {
                if startOffset + lineLength < selectedAttrText.length {
                    let newlineRange = NSRange(location: startOffset + lineLength, length: 1)
                    if newlineRange.location + newlineRange.length <= selectedAttrText.length {
                        let newlineAttr = selectedAttrText.attributedSubstring(from: newlineRange)
                        resultText.append(newlineAttr)
                    } else {
                        resultText.append(NSAttributedString(string: "\n", attributes: [
                            .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
                            .foregroundColor: NSColor.white
                        ]))
                    }
                }
            }
            
            // Обновляем смещение для следующей строки
            startOffset += lineLength + (index < lines.count - 1 ? 1 : 0)
        }
        
        textStorage.replaceCharacters(in: currentRange, with: resultText)
        attributedText = textStorage
        updateNoteContent()
    }
    
    // Вспомогательная функция для очистки маркеров списка
    private func cleanListMarkers(_ text: String) -> String {
        var result = text
        
        // Удаляем маркеры маркированного списка
        if result.hasPrefix("• ") {
            result = String(result.dropFirst(2))
        }
        
        // Удаляем маркеры нумерованного списка
        if let range = result.range(of: #"^\d+\. "#, options: .regularExpression) {
            result = String(result[range.upperBound...])
        }
        
        // Удаляем чекбоксы
        if result.hasPrefix("☐ ") || result.hasPrefix("☑ ") {
            result = String(result.dropFirst(2))
        }
        
        return result
    }
    
    // Функция обработки вставки изображения из буфера обмена
    private func pasteImageFromClipboard() {
        let pasteboard = NSPasteboard.general
        
        // Проверяем, есть ли изображение в буфере обмена
        if let image = NSImage(pasteboard: pasteboard) {
            // Сохраняем изображение и вставляем его
            insertImageFromNSImage(image)
        }
    }
    
    // Функция для вставки изображения из NSImage
    private func insertImageFromNSImage(_ image: NSImage) {
        guard !selectedRanges.isEmpty, let currentRange = selectedRanges.first?.rangeValue else { return }
        
        // Генерируем уникальное имя файла
        let imageName = generateUniqueImageName()
        let imageURL = getImagesDirectory().appendingPathComponent("\(imageName).png")
        
        // Сохраняем изображение на диск
        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            
            do {
                try pngData.write(to: imageURL)
                
                // Создаем вложение для NSTextAttachment
                let attachment = NSTextAttachment()
                attachment.image = image
                
                // Если изображение слишком большое, уменьшаем его
                let maxWidth: CGFloat = 600
                if image.size.width > maxWidth {
                    let aspectRatio = image.size.height / image.size.width
                    let newHeight = maxWidth * aspectRatio
                    attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: newHeight)
                }
                
                // Создаем атрибутированную строку с вложением
                let attributedString = NSAttributedString(attachment: attachment)
                
                // Добавляем дополнительный атрибут для идентификации изображения
                let mutableAttrString = NSMutableAttributedString(attributedString: attributedString)
                mutableAttrString.addAttribute(.link, value: imageURL.path, range: NSRange(location: 0, length: mutableAttrString.length))
                
                // Добавляем пробел после изображения с белым цветом текста
                let whiteSpace = NSAttributedString(
                    string: " ",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
                        .foregroundColor: NSColor.white
                    ]
                )
                mutableAttrString.append(whiteSpace)
                
                // Вставляем изображение в текст
                let textStorage = NSTextStorage(attributedString: attributedText)
                textStorage.replaceCharacters(in: currentRange, with: mutableAttrString)
                attributedText = textStorage
                updateNoteContent()
                
                // Обновляем редактор, чтобы установить правильный цвет для последующего текста
                DispatchQueue.main.async {
                    self.setDefaultTextColor()
                }
                
            } catch {
                print("Ошибка при сохранении изображения: \(error)")
            }
        }
    }
    
    // Функция для установки цвета текста по умолчанию
    private func setDefaultTextColor() {
        let selectedRange = NSRange(location: attributedText.length, length: 0)
        let textStorage = NSTextStorage(attributedString: attributedText)
        
        // Устанавливаем белый цвет текста и шрифт для точки вставки
        let typingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
            .foregroundColor: NSColor.white
        ]
        
        // Добавляем атрибуты к текущей точке вставки
        textStorage.addAttributes(typingAttributes, range: selectedRange)
        attributedText = textStorage
        
        // Установка выделения в конец
        selectedRanges = [NSValue(range: selectedRange)]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Панель инструментов
            HStack(spacing: 12) {
                Button(action: makeTextBold) {
                    Image(systemName: "bold")
                        .frame(width: 30, height: 30)
                }
                
                Button(action: makeTextItalic) {
                    Image(systemName: "italic")
                        .frame(width: 30, height: 30)
                }
                
                Button(action: makeTextUnderlined) {
                    Image(systemName: "underline")
                        .frame(width: 30, height: 30)
                }
                
                Divider()
                    .frame(height: 20)
                
                Menu {
                    Button("Заголовок 1") { makeHeading(level: 1) }
                    Button("Заголовок 2") { makeHeading(level: 2) }
                    Button("Заголовок 3") { makeHeading(level: 3) }
                } label: {
                    Image(systemName: "textformat.size")
                        .frame(width: 30, height: 30)
                }
                
                Divider()
                    .frame(height: 20)
               
                Button(action: insertBulletedList) {
                    Image(systemName: "list.bullet")
                        .frame(width: 30, height: 30)
                }
                
                Button(action: insertNumberedList) {
                    Image(systemName: "list.number")
                        .frame(width: 30, height: 30)
                }
                
                Button(action: insertChecklist) {
                    Image(systemName: "checkmark.square")
                        .frame(width: 30, height: 30)
                }
                
                Divider()
                    .frame(height: 20)
                
                Button(action: pasteImageFromClipboard) {
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
            
            // Настоящий редактор форматированного текста
            RichTextViewRepresentable(
                text: $attributedText,
                textDidChange: { newText in
                    self.attributedText = newText
                    updateNoteContent()
                },
                selectedRanges: $selectedRanges,
                onPasteImage: { image in
                    self.insertImageFromNSImage(image)
                }
            )
            .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
            .cornerRadius(8)
            .padding()
        }
        .onAppear {
            // При появлении загружаем сохраненный форматированный текст
            if let data = note.contentData,
               let attributedString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {
                self.attributedText = attributedString
            } else {
                // Если форматированного текста нет, создаем его из обычного текста
                self.attributedText = NSAttributedString(
                    string: note.content,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: CGFloat(fontSize)),
                        .foregroundColor: colorScheme == .dark ? NSColor.white : NSColor.black
                    ]
                )
            }
        }
        .sheet(isPresented: $showingInsertImage) {
            ImagePickerView(onImageSelected: { imageName in
                if let image = NSImage(named: imageName) {
                    insertImageFromNSImage(image)
                }
            })
        }
        .sheet(isPresented: $showingLinkEditor) {
            LinkEditorView(url: $linkURL, title: $linkTitle, onInsert: insertLink)
        }
    }
    
    private func insertImage(_ imageName: String) {
        guard !selectedRanges.isEmpty, let currentRange = selectedRanges.first?.rangeValue else { return }
        
        let textStorage = NSTextStorage(attributedString: attributedText)
        let imageText = NSAttributedString(string: "[Изображение: \(imageName)]", attributes: [.font: NSFont.systemFont(ofSize: CGFloat(fontSize))])
        textStorage.replaceCharacters(in: currentRange, with: imageText)
        attributedText = textStorage
        updateNoteContent()
    }
    
    private func insertLink() {
        guard !selectedRanges.isEmpty, let currentRange = selectedRanges.first?.rangeValue else { return }
        
        let linkText = linkTitle.isEmpty ? linkURL : linkTitle
        
        let textStorage = NSTextStorage(attributedString: attributedText)
        
        if currentRange.length > 0 {
            // Если текст выделен, делаем его ссылкой
            let linkAttributes: [NSAttributedString.Key: Any] = [
                .link: URL(string: linkURL) ?? URL(string: "https://example.com")!,
                .foregroundColor: NSColor.blue,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
            textStorage.addAttributes(linkAttributes, range: currentRange)
        } else {
            // Если текст не выделен, вставляем новую ссылку
            let linkAttributedString = NSAttributedString(
                string: linkText,
                attributes: [
                    .link: URL(string: linkURL) ?? URL(string: "https://example.com")!,
                    .foregroundColor: NSColor.blue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .font: NSFont.systemFont(ofSize: CGFloat(fontSize))
                ]
            )
            textStorage.replaceCharacters(in: currentRange, with: linkAttributedString)
        }
        
        attributedText = textStorage
        updateNoteContent()
        
        linkURL = ""
        linkTitle = ""
    }
    
    private func sharePlainText() {
        let sharingItems: [Any] = [note.title, attributedText.string]
        let sharingService = NSSharingServicePicker(items: sharingItems)
        
        if let window = NSApplication.shared.windows.first {
            sharingService.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
        }
    }
}

// Вспомогательные представления
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
                Section("Детали ссылки") {
                    TextField("URL", text: $url)
                    TextField("Заголовок", text: $title)
                }
            }
            .navigationTitle("Вставить ссылку")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Вставить") {
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
