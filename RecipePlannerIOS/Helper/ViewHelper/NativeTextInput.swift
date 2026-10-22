import SwiftUI
import UIKit

struct NativeTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var textColor: UIColor = .white
    var placeholderColor: UIColor = UIColor.white.withAlphaComponent(0.45)
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var autocorrectionType: UITextAutocorrectionType = .default
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var keyboardType: UIKeyboardType = .default
    var returnKeyType: UIReturnKeyType = .default

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.text = text
        textField.textColor = textColor
        textField.tintColor = .systemGreen
        textField.font = font
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.autocorrectionType = autocorrectionType
        textField.autocapitalizationType = autocapitalizationType
        textField.keyboardType = keyboardType
        textField.returnKeyType = returnKeyType
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        updatePlaceholder(for: textField, locale: context.environment.locale)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.textColor = textColor
        uiView.font = font
        uiView.autocorrectionType = autocorrectionType
        uiView.autocapitalizationType = autocapitalizationType
        uiView.keyboardType = keyboardType
        uiView.returnKeyType = returnKeyType
        updatePlaceholder(for: uiView, locale: context.environment.locale)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    static func dismantleUIView(_ uiView: UITextField, coordinator: Coordinator) {
        uiView.delegate = nil
        uiView.removeTarget(
            coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
    }

    private func updatePlaceholder(for textField: UITextField, locale: Locale) {
        textField.attributedPlaceholder = NSAttributedString(
            string: String(localized: String.LocalizationValue(placeholder), locale: locale),
            attributes: [.foregroundColor: placeholderColor]
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func textDidChange(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            text = textField.text ?? ""
        }
    }
}

struct NativeTextView: UIViewRepresentable {
    @Binding var text: String
    var textColor: UIColor = .white
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var autocorrectionType: UITextAutocorrectionType = .default
    var autocapitalizationType: UITextAutocapitalizationType = .sentences

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.text = text
        textView.textColor = textColor
        textView.font = font
        textView.backgroundColor = .clear
        textView.tintColor = .systemGreen
        textView.autocorrectionType = autocorrectionType
        textView.autocapitalizationType = autocapitalizationType
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 2, bottom: 8, right: 2)
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.textColor = textColor
        uiView.font = font
        uiView.autocorrectionType = autocorrectionType
        uiView.autocapitalizationType = autocapitalizationType
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        uiView.delegate = nil
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            text = textView.text
        }
    }
}
