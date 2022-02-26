import SwiftSyntax

extension Optional where Wrapped == ModifierListSyntax {
    var isFinal: Bool {
        self?.isFinal ?? false
    }

    var isStatic: Bool {
        self?.isStatic ?? false
    }
}

extension ModifierListSyntax {
    var isFinal: Bool {
        contains { $0.name.tokenKind == .identifier("final") }
    }

    var isStatic: Bool {
        contains { $0.name.tokenKind == .staticKeyword }
    }
}
