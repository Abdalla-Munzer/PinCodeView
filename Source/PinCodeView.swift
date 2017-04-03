//
//  PinCodeView.swift
//  PinCodeView
//
//  Created by Ariel Pollack on 02/04/2017.
//  Copyright © 2017 Dapulse. All rights reserved.
//

import UIKit

public class PinCodeView: UIStackView {
    
    public enum TextType {
        case numbers
        case numbersAndLetters
    }
    
    fileprivate enum State {
        case inserting(Int)
        case finished
        case disabled
    }
    
    public weak var delegate: PinCodeViewDelegate?
    public var textType: TextType = .numbers
    @IBInspectable public var numberOfDigits: Int = 6
    @IBInspectable public var groupingSize: Int = 3
    @IBInspectable public var itemSpacing: Int = 2
    public var viewConfig: PinCodeDigitView.ViewConfigBlock = { state, view in
        // default impl
        
        view.layer.borderWidth = 1
        view.font = UIFont.systemFont(ofSize: 20)
        
        switch state {
        case .empty, .hasDigit:
            view.layer.borderColor = UIColor.blue.cgColor
            
        case .failedVerification:
            view.layer.borderColor = UIColor.red.cgColor
        }
    }
    
    fileprivate var digitViews = [PinCodeDigitView]()
    fileprivate var digitState: State = .inserting(0) {
        didSet {
            if case .inserting(0) = digitState {
                clearText()
            }
        }
    }
    
    public init(numberOfDigits: Int = 6, textType: TextType = .numbers, groupingSize: Int = 3, itemSpacing: Int = 2) {
        super.init(frame: .zero)
        
        self.numberOfDigits = numberOfDigits
        self.textType = textType
        self.groupingSize = groupingSize
        self.itemSpacing = itemSpacing
        
        configure()
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required public init(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    private func configure() {
        self.axis = .horizontal
        self.distribution = .fill
        self.translatesAutoresizingMaskIntoConstraints = false
        
        configureGestures()
    }
    
    private func configureGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress))
        longPress.minimumPressDuration = 0.25
        addGestureRecognizer(longPress)
    }
    
    private func configureDigitViews() {
        self.spacing = CGFloat(itemSpacing)
        
        self.arrangedSubviews.forEach { view in
            self.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        digitViews = []
        
        for _ in 0..<numberOfDigits {
            let digitView = PinCodeDigitView(viewConfig: self.viewConfig)
            digitView.translatesAutoresizingMaskIntoConstraints = false
            self.addArrangedSubview(digitView)
            digitViews.append(digitView)
        }
        
        if groupingSize > 0 {
            // TODO: better custom separators
            for idx in stride(from: groupingSize, to: numberOfDigits, by: groupingSize).reversed() {
                let separator = PinCodeSeparatorView(text: "-")
                self.insertArrangedSubview(separator, at: idx)
            }
        }
    }
    
    private var didLayoutSubviews = false
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if !didLayoutSubviews {
            didLayoutSubviews = true
            configureDigitViews()
        }
    }
    
    func didTap() {
        guard !self.isFirstResponder else { return }
        becomeFirstResponder()
    }
    
    func didLongPress(gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        if !self.isFirstResponder  {
            self.becomeFirstResponder()
        }
        
        UIMenuController.shared.setTargetRect(self.bounds, in: self)
        UIMenuController.shared.setMenuVisible(true, animated: true)
    }
    
    // MARK: handle text input
    fileprivate var text: String {
        return digitViews.reduce("", { text, digitView in
            return text + (digitView.digit ?? "")
        })
    }
    
    func clearText() {
        for digitView in digitViews {
            digitView.digit = nil
        }
    }
    
    func submitDigits() {
        digitState = .disabled
        delegate?.pinCodeView(self, didSubmitPinCode: text, isValidCallback: { [weak self] (isValid) in
            // we don't care about valid, the delegate will do something
            guard !isValid, let zelf = self else { return }
            
            zelf.digitState = .finished
            
            for digitView in zelf.digitViews {
                digitView.state = .failedVerification
            }
            
            zelf.animateFailure()
        })
    }
    
    private func animateFailure() {
        let anim = CABasicAnimation(keyPath: "position")
        anim.fromValue = NSValue(cgPoint: CGPoint(x: center.x - 10, y: center.y))
        anim.toValue = NSValue(cgPoint: CGPoint(x: center.x + 10, y: center.y))
        anim.duration = 0.05
        anim.repeatCount = 2
        anim.autoreverses = true
        layer.add(anim, forKey: "position")
    }
}

extension PinCodeView {
    override public func paste(_ sender: Any?) {
        guard let string = UIPasteboard.general.string else { return }
        let text: String
        switch textType{
        case .numbers:
            text = string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            
        case .numbersAndLetters:
            text = string.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        }
        
        insertText(text)
    }
    
    override public var canBecomeFirstResponder: Bool {
        return true
    }
    
    override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(paste(_:))
    }
    
    public var keyboardType: UIKeyboardType {
        get {
            switch textType {
            case .numbers:
                return .numberPad
                
            case .numbersAndLetters:
                return .default
            }
        }
        set {
            // ignore manual user set
        }
    }
}

extension PinCodeView: UIKeyInput {
    public var hasText: Bool {
        return text.characters.count > 0
    }
    
    private func isValidText(_ text: String) -> Bool {
        guard text.characters.count > 0 else {
            return false
        }
        
        let validCharacterSet: CharacterSet
        switch textType {
        case .numbers:
            validCharacterSet = .decimalDigits
            
        case .numbersAndLetters:
            validCharacterSet = .alphanumerics
        }
        
        guard validCharacterSet.contains(UnicodeScalar(text)!) else {
            return false
        }
        
        return true
    }
    
    public func insertText(_ text: String) {
        if case .disabled = digitState { return }
        
        // if inserting more than 1 character, reset all values and put new text
        guard text.characters.count == 1 else {
            digitState = .inserting(0)
            text.characters.map({ "\($0)" }).forEach(insertText)
            return
        }
        
        guard isValidText(text) else { return }
        
        delegate?.pinCodeView(self, didInsertText: text)
        
        // state machine
        switch digitState {
        case .inserting(let digitIndex):
            let digitView = digitViews[digitIndex]
            digitView.digit = text
            
            if digitIndex + 1 == numberOfDigits {
                digitState = .finished
                submitDigits()
            } else {
                digitState = .inserting(digitIndex + 1)
            }
            
        case .finished:
            digitState = .inserting(0)
            insertText(text)
            
        default: break
        }
        
    }
    
    public func deleteBackward() {
        delegate?.pinCodeView(self, didInsertText: "")
        
        switch digitState {
        case .inserting(let index) where index > 0:
            let digitView = digitViews[index - 1]
            digitView.digit = nil
            
            digitState = .inserting(index - 1)
            
        case .finished:
            digitState = .inserting(0)
            
        default: break
        }
    }
}
