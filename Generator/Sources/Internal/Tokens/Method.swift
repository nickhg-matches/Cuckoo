import Foundation

struct Method: Token, HasAttributes, HasAccessibility, HasName {
    var parent: Reference<Token>?

    var attributes: [Attribute]
    var accessibility: Accessibility
    var name: String
    var signature: Signature
    var isOptional: Bool
    var isOverriding: Bool

    var fullSignature: String {
        [
            accessibility.sourceName,
            "\(name)\(signature.description)",
        ]
        .compactMap { $0.nilIfEmpty }
        .joined(separator: " ")
    }
}

extension Method: Inheritable {
    func isEqual(to other: Inheritable) -> Bool {
        guard let other = other as? Method else { return false }
        return name == other.name && signature.isApiEqual(to: other.signature)
    }
}

extension Method {
    var fullyQualifiedName: String {
        "\(name)\(signature.description.indented(times: 3).trimmed)"
    }
    
    var isAsync: Bool {
        signature.asyncType.map { $0.isAsync || $0.isReasync } ?? false
    }
    
    var isThrowing: Bool {
        signature.throwType.map { $0.isThrowing || $0.isRethrowing } ?? false
    }

    var returnType: WrappableType? {
        signature.returnType
    }

    var hasClosureParams: Bool {
        signature.parameters.contains { $0.isClosure }
    }

    var hasOptionalParams: Bool {
        signature.parameters.contains { $0.isOptional }
    }

    func serialize() -> [String : Any] {
        let call = signature.parameters
            .map { parameter in
                let name = escapeReservedKeywords(for: parameter.usableName)
                let value = "\(parameter.isInout ? "&" : "")\(name)\(parameter.isAutoClosure ? "()" : "")"
                if parameter.name == "_" {
                    return value
                } else {
                    return "\(parameter.name): \(value)"
                }
            }
            .joined(separator: ", ")

        guard let parent else {
            fatalError("Failed to find parent of method \(fullSignature). Please file a bug.")
        }
        let stubFunctionPrefix = parent.isClass ? "Class" : "Protocol"
        let returnString = returnType == nil || returnType?.sugarized == "Void" ? "NoReturn" : ""
        let throwingString = isThrowing ? "Throwing" : ""
        let stubFunction = "Cuckoo.\(stubFunctionPrefix)Stub\(returnString)\(throwingString)Function"

        let escapingParameterNames = signature.parameters.map { parameter in
            if parameter.isClosure && !parameter.isEscaping {
                let parameterCount = parameter.closureParamCount
                let parameterSignature = parameterCount > 0 ? (1...parameterCount).map { _ in "_" }.joined(separator: ", ") : "()"

                // FIXME: Instead of parsing the closure return type here, Tokenizer should do it and pass the information in a data structure
                let returnSignature: String
                let closureReturnType = extractClosureReturnType(parameter: parameter.type.sugarized)
                if let closureReturnType = closureReturnType, !closureReturnType.isEmpty && closureReturnType != "Void" {
                    returnSignature = " -> " + closureReturnType
                } else {
                    returnSignature = ""
                }
                return "{ \(parameterSignature)\(returnSignature) in fatalError(\"This is a stub! It's not supposed to be called!\") }"
            } else {
                return parameter.usableName
            }
        }.joined(separator: ", ")

        return [
            "self": self,
            "isOverriding": isOverriding,
            "name": name,
            "accessibility": accessibility.sourceName,
            "signature": signature.description,
            "parameters": signature.parameters,
            "parameterNames": signature.parameters.map { escapeReservedKeywords(for: $0.usableName) }.joined(separator: ", "),
            "escapingParameterNames": escapingParameterNames,
            "returnType": returnType?.explicitOptionalOnly.sugarized ?? "",
            "isAsync": isAsync,
            "isThrowing": isThrowing,
            "throwType": signature.throwType?.description ?? "",
            "fullyQualifiedName": fullyQualifiedName,
            "call": call,
            "parameterSignature": signature.parameters.map { $0.description }.joined(separator: ", "),
            "parameterSignatureWithoutNames": signature.parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", "),
            "argumentSignature": signature.parameters.map { $0.type.description }.joined(separator: ", "),
            "stubFunction": stubFunction,
            "inputTypes": signature.parameters.map { $0.typeWithoutAttributes }.joined(separator: ", "),
            "isOptional": isOptional,
            "hasClosureParams": hasClosureParams,
            "hasOptionalParams": hasOptionalParams,
            "attributes": attributes,
            "genericParameters": signature.genericParameters.sourceDescription,
            "hasUnavailablePlatforms": hasUnavailablePlatforms,
            "unavailablePlatformsCheck": unavailablePlatformsCheck,
        ]
    }

    private func extractClosureReturnType(parameter: String) -> String? {
        var parenLevel = 0
        for i in 0..<parameter.count {
            let index = parameter.index(parameter.startIndex, offsetBy: i)
            let character = parameter[index]
            if character == "(" {
                parenLevel += 1
            } else if character == ")" {
                parenLevel -= 1
                if parenLevel == 0 {
                    let returnSignature = String(parameter[parameter.index(after: index)..<parameter.endIndex])
                    let regex = try! NSRegularExpression(pattern: "\\s*->\\s*(.*)\\s*")
                    guard let result = regex.matches(in: returnSignature, range: NSRange(location: 0, length: returnSignature.count)).first else { return nil }
                    return returnSignature[result.range(at: 1)]
                }
            }
        }

        return nil
    }
}
