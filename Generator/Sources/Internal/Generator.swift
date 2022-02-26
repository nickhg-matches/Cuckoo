import Foundation
import Stencil

struct Generator {
    private static let extensions = createExtensions()

    static func generate(tokens: [Token], debug: Bool = false) throws -> String {
        let containers = tokens.map { $0.serialize() }

        let environment = Environment(
            extensions: extensions,
            trimBehaviour: .smart
        )
        return try environment.renderTemplate(string: Templates.mock, context: ["containers": containers, "debug": debug])
    }

    private static func matchableGenericTypes(from method: Method) -> String {
        guard !method.signature.parameters.isEmpty || !method.signature.genericParameters.isEmpty else { return "" }

        let matchableGenericParameters = method.signature.parameters.enumerated().map { index, parameter -> String in
            let type = parameter.isOptional ? "OptionalMatchable" : "Matchable"
            return "M\(index + 1): Cuckoo.\(type)"
        }
        let methodGenericParameters = method.signature.genericParameters.map { $0.description }
        return "<\((matchableGenericParameters + methodGenericParameters).joined(separator: ", "))>"
    }

    private static func matchableGenericsWhereClause(from method: Method) -> String {
        guard method.signature.parameters.isEmpty == false else { return "" }

        let matchableWhereConstraints = method.signature.parameters.enumerated().map { index, parameter -> String in
            let type = parameter.isOptional ? "OptionalMatchedType" : "MatchedType"
            return "M\(index + 1).\(type) == \(genericSafeType(from: parameter.type.withoutAttributes.unoptionaled.sugarized))"
        }
        let methodWhereConstraints = method.signature.whereConstraints
        return " where \((matchableWhereConstraints + methodWhereConstraints).joined(separator: ", "))"
    }

    private static func matchableParameterSignature(with parameters: [MethodParameter]) -> String {
        guard !parameters.isEmpty else { return "" }

        return parameters.enumerated()
            .map { "\($1.nameAndInnerName): M\($0 + 1)" }
            .joined(separator: ", ")
    }

    private static func parameterMatchers(for parameters: [MethodParameter]) -> String {
        guard parameters.isEmpty == false else { return "let matchers: [Cuckoo.ParameterMatcher<Void>] = []" }

        let tupleType = parameters.map { $0.typeWithoutAttributes }.joined(separator: ", ")
        let matchers = parameters
            .compactMap { parameter -> MethodParameter? in
                if parameter.usableName == nil {
                    return nil
                } else {
                    return parameter
                }
            }
            // Enumeration is done after filtering out parameters without usable names.
            .enumerated()
            .compactMap { index, parameter in
                let name = escapeReservedKeywords(for: parameter.usableName)
                return "wrap(matchable: \(name)) { $0\(parameters.count > 1 ? ".\(index)" : "") }"
            }
            .joined(separator: ", ")
        return "let matchers: [Cuckoo.ParameterMatcher<(\(genericSafeType(from: tupleType)))>] = [\(matchers)]"
    }

    private static func genericSafeType(from type: String) -> String {
        return type.replacingOccurrences(of: "!", with: "?")
    }

    private static func openNestedClosure(for method: Method) -> String {
        var fullString = ""
        for (index, parameter) in method.signature.parameters.enumerated() {
            if parameter.isClosure && !parameter.isEscaping {
                let indents = String(repeating: "\t", count: index)
                let tries = method.isThrowing ? "try " : ""
                let awaits = method.isAsync ? "await " : ""

                let sugarizedReturnType = method.returnType?.sugarized
                let returnSignature: String
                if let sugarizedReturnType {
                    if sugarizedReturnType.isEmpty {
                        returnSignature = sugarizedReturnType
                    } else {
                        returnSignature = " -> \(sugarizedReturnType)"
                    }
                } else {
                    returnSignature = ""
                }

                fullString += "\(indents)return \(tries)\(awaits)withoutActuallyEscaping(\(parameter.usableName), do: { (\(parameter.usableName): @escaping \(parameter.type))\(returnSignature) in\n"
            }
        }

        return fullString
    }

    private static func closeNestedClosure(for parameters: [MethodParameter]) -> String {
        var fullString = ""
        for (index, parameter) in parameters.enumerated() {
            if parameter.isClosure && !parameter.isEscaping {
                let indents = String(repeating: "\t", count: index)
                fullString += "\(indents)})\n"
            }
        }
        return fullString
    }

    private static func removeClosureArgumentNames(for type: String) -> String {
        type.replacingOccurrences(
            of: "_\\s+?[_a-zA-Z]\\w*?\\s*?:",
            with: "",
            options: .regularExpression
        )
    }
}

extension Generator {
    private static func createExtensions() -> [Extension] {
        let stencilExtension = Extension()

        stencilExtension
            .registeringFilter("genericSafe") { (value: Any?) in
                guard let string = value as? String else { return value }
                return genericSafeType(from: string)
            }
            .registeringFilter("matchableGenericNames") { (value: Any?) in
                guard let method = value as? Method else { return value }
                return matchableGenericTypes(from: method)
            }
            .registeringFilter("matchableGenericWhereClause") { (value: Any?) in
                guard let method = value as? Method else { return value }
                return matchableGenericsWhereClause(from: method)
            }
            .registeringFilter("matchableParameterSignature") { (value: Any?) in
                guard let parameters = value as? [MethodParameter] else { return value }
                return matchableParameterSignature(with: parameters)
            }
            .registeringFilter("parameterMatchers") { (value: Any?) in
                guard let parameters = value as? [MethodParameter] else { return value }
                return parameterMatchers(for: parameters)
            }
            .registeringFilter("openNestedClosure") { (value: Any?) in
                guard let method = value as? Method else { return value }
                return openNestedClosure(for: method)
            }
            .registeringFilter("closeNestedClosure") { (value: Any?) in
                guard let parameters = value as? [MethodParameter] else { return value }
                return closeNestedClosure(for: parameters)
            }
            .registeringFilter("escapeReservedKeywords") { (value: Any?) in
                guard let name = value as? String else { return value }
                return escapeReservedKeywords(for: name)
            }
            .registeringFilter("removeClosureArgumentNames") { (value: Any?) in
                guard let type = value as? String else { return value }
                return removeClosureArgumentNames(for: type)
            }
            .registeringFilter("withSpace") { (value: Any?) in
                if let value = value as? String, !value.isEmpty {
                    return "\(value) "
                } else {
                    return ""
                }
            }

        return [stencilExtension]
    }
}

extension Extension {
    @discardableResult
    fileprivate func registeringFilter(_ name: String, filter: @escaping (Any?) throws -> Any?) -> Self {
        registerFilter(name, filter: filter)
        return self
    }

    fileprivate func registeringFilter(_ name: String, filter: @escaping (Any?, [Any?]) throws -> Any?) -> Self {
        registerFilter(name, filter: filter)
        return self
    }

    fileprivate func registeringFilter(_ name: String, filter: @escaping (Any?, [Any?], Context) throws -> Any?) -> Self {
        registerFilter(name, filter: filter)
        return self
    }
}
