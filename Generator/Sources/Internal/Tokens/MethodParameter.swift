struct MethodParameter: Token {
    var parent: Reference<Token>?

    var name: String
    var innerName: String?
    var type: WrappableType
    var isInout: Bool

    var nameAndInnerName: String {
        [name, innerName].compactMap { $0 }.joined(separator: " ")
    }

    var usableName: String {
        innerName ?? name
//        if name == "_" {
//            guard let innerName else {
//                fatalError("Parameter inner name shouldn't be empty if name is an underscore. Please file a bug.")
//            }
//            return innerName
//        } else {
//            return name
//        }
    }

    var description: String {
        "\(nameAndInnerName): \(isInout ? "inout " : "")\(type)"
    }

    var typeWithoutAttributes: String {
        type.withoutAttributes.sugarized.trimmed
    }

    var isClosure: Bool {
        typeWithoutAttributes.hasPrefix("(") && typeWithoutAttributes.range(of: "->") != nil
    }

    var isAutoClosure: Bool {
        type.containsAttribute(named: "@autoclosure")
    }

    var isOptional: Bool {
        type.isOptional
    }

    var closureParamCount: Int {
        // make sure that the parameter is a closure and that it's not just an empty `() -> ...` closure
        guard isClosure && !"^\\s*\\(\\s*\\)".regexMatches(typeWithoutAttributes) else { return 0 }

        var parenLevel = 0
        var parameterCount = 1
        for character in typeWithoutAttributes {
            switch character {
            case "(", "<":
                parenLevel += 1
            case ")", ">":
                parenLevel -= 1
            case ",":
                parameterCount += parenLevel == 1 ? 1 : 0
            default:
                break
            }
            if parenLevel == 0 {
                break
            }
        }

        return parameterCount
    }

    var isEscaping: Bool {
        isClosure && (type.containsAttribute(named: "@escaping") || type.isOptional)
    }

    func serialize() -> [String: Any] {
        return [
            "name": name,
            "innerName": innerName ?? "",
            "type": type,
            "nameAndInnerName": nameAndInnerName,
            "typeWithoutAttributes": typeWithoutAttributes,
            "isClosure": isClosure,
            "isOptional": isOptional,
            "isEscaping": isEscaping
        ]
    }
}
