import Foundation
import SwiftSyntax
import SwiftSyntaxParser

final class Crawler: SyntaxVisitor {
    static func crawl(url: URL) throws -> Crawler {
        let syntaxTree = try SyntaxParser.parse(url)
        #if DEBUG
        // Comment out the line above and uncomment the one below to test specific strings.
        // The `testString` is at the bottom of this file.
//        let syntaxTree = try SyntaxParser.parse(source: testString)
        #endif
        let crawler = Self(container: nil)
        crawler.walk(syntaxTree)
        return crawler
    }

    var imports: [Import] = []
    var tokens: [Token] = []

    private var container: Reference<Token>?

    private init(container: Reference<Token>?) {
        self.container = container
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let path = node.path.description
        if let importKind = node.importKind?.withoutTrivia().description {
            // Component import.
            imports.append(.component(kind: importKind, name: path))
        } else {
            // Target import.
            imports.append(.library(name: path))
        }
        return .skipChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        log(node)

        // Skip `final` classes.
        guard !node.modifiers.isFinal else { return .skipChildren }

        var token = ClassDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? (container as? HasAccessibility)?.accessibility ?? .internal,
            name: node.identifier.withoutTrivia().description,
            genericParameters: genericParameters(from: node.genericParameterClause?.genericParameterList),
            genericRequirements: genericRequirements(from: node.genericWhereClause?.requirementList),
            inheritedTypes: inheritedTypes(from: node.inheritanceClause?.inheritedTypeCollection),
            members: []
        )

        // Early return for private namespace.
        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token))
        crawler.walk(members: node.members)
        token.members = crawler.tokens
        tokens.append(token)
        return .skipChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        log(node)
        let inheritedTypes = inheritedTypes(from: node.inheritanceClause?.inheritedTypeCollection)
        var token = ProtocolDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? (container as? HasAccessibility)?.accessibility ?? .internal,
            name: node.identifier.withoutTrivia().description,
            genericParameters: genericParameters(from: node.primaryAssociatedTypeClause?.primaryAssociatedTypeList) + associatedTypes(from: node.members.members),
            genericRequirements: genericRequirements(from: node.genericWhereClause?.requirementList),
            inheritedTypes: inheritedTypes,
            members: []
        )

        // Early return for private namespace.
        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token))
        crawler.walk(members: node.members)
        token.members = crawler.tokens
        tokens.append(token)
        return .skipChildren
    }

    // Enum mocking is not supported, this is used to parse nested classes.
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        log(node)
        var token = NamespaceDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? (container as? HasAccessibility)?.accessibility ?? .internal,
            name: node.identifier.withoutTrivia().description,
            members: []
        )

        // Early return for private namespace.
        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token))
        crawler.walk(members: node.members)
        token.members = crawler.tokens
        tokens.append(token)
        return .skipChildren
    }

    // Extension mocking is not supported, this is used to parse nested classes.
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        log(node)
        var token = NamespaceDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? (container as? HasAccessibility)?.accessibility ?? .internal,
            name: node.extendedType.withoutTrivia().description,
            members: []
        )

        // Early return for private namespace.
        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token))
        crawler.walk(members: node.members)
        token.members = crawler.tokens
        tokens.append(token)
        return .skipChildren
    }

    // Struct mocking is not supported, this is used to parse nested classes.
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        log(node)
        var token = NamespaceDeclaration(
            parent: container,
            attributes: attributes(from: node.attributes),
            accessibility: accessibility(from: node.modifiers) ?? (container as? HasAccessibility)?.accessibility ?? .internal,
            name: node.identifier.withoutTrivia().description,
            members: []
        )

        // Early return for private namespace.
        guard token.accessibility.isAccessible else { return .skipChildren }

        let crawler = Crawler(container: Reference(token))
        crawler.walk(members: node.members)
        token.members = crawler.tokens
        tokens.append(token)
        return .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard container?.isMockable != false else { return .skipChildren }

        tokens.append(contentsOf: parse(node.withoutTrivia()))
        return .skipChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard container?.isMockable != false else { return .skipChildren }

        // TODO: Print the error.
        if let initializer = try! parse(node.withoutTrivia()) {
            tokens.append(initializer)
        }
        return .skipChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard container?.isMockable != false else { return .skipChildren }

        // TODO: Print the error.
        if let method = try! parse(node.withoutTrivia()) {
            tokens.append(method)
        }
        return .skipChildren
    }

    private func walk(members: MemberDeclBlockSyntax) {
        for member in members.members {
            walk(member.withoutTrivia())
        }
    }

    private func log(_ node: DeclSyntaxProtocol, additionalInfo: String? = nil) {
        #if !DEBUG
        return
        #endif

        let description: String
        switch node {
        case let node as ClassDeclSyntax:
            description = "class \(node.identifier.withoutTrivia().description)"
        case let node as ProtocolDeclSyntax:
            description = "protocol \(node.identifier.withoutTrivia().description)"
        case let node as StructDeclSyntax:
            description = "struct \(node.identifier.withoutTrivia().description)"
        case let node as ExtensionDeclSyntax:
            description = "extension \(node.extendedType.withoutTrivia().description)"
        default:
            description = "Unknown declaration \(node.withoutTrivia().description)"
        }

        print([description, additionalInfo].compactMap { $0 }.joined(separator: " "))
    }
}

// MARK: - Variable crawling.
extension Crawler {
    private func parse(_ variableGroup: VariableDeclSyntax) -> [Variable] {
        let isConstant = variableGroup.letOrVarKeyword.tokenKind == .letKeyword

        guard !isConstant && !variableGroup.modifiers.isStatic && !variableGroup.modifiers.isFinal else { return [] }

        let attributes = attributes(from: variableGroup.attributes)

        var accessibility = Accessibility.internal
        var setterAccessibility: Accessibility?
        if let modifiers = variableGroup.modifiers {
            for modifier in modifiers {
                let tokenKind = modifier.name.tokenKind

                guard let parsedAccessibility = Accessibility(tokenKind: tokenKind) else {
                    continue
                }

                if case .identifier(let detail) = modifier.detail?.tokenKind, detail == "set" {
                    setterAccessibility = parsedAccessibility
                } else {
                    accessibility = parsedAccessibility
                }
            }
        }

        // Unnecessary now, but might come in handy later.
//        let isOverriding = variableGroup.modifiers?.contains { $0.name.tokenKind == .identifier("override") } ?? false

        return variableGroup.bindings
            .compactMap(variable(from:))
            .map {
                Variable(
                    parent: container,
                    attributes: attributes,
                    accessibility: accessibility,
                    setterAccessibility: $0.isReadOnly ? nil : setterAccessibility ?? (container as? HasAccessibility)?.accessibility ?? .internal,
                    name: $0.identifier,
                    type: $0.type,
                    effects: $0.effects,
                    isOverriding: container?.isClass ?? false
                )
            }
    }

    private func variable(from binding: PatternBindingSyntax) -> VariablePart? {
        guard case .identifier(let identifier) = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.tokenKind else { return nil }

        let type: String
        if let explicitType = binding.typeAnnotation?.type.withoutTrivia().description {
            type = explicitType
        } else if let initializer = binding.initializer?.value.withoutTrivia().description {
            type = TypeGuesser.guessType(from: initializer)!
        } else {
            fatalError("TODO: Can't infer type.")
        }

        let isReadOnly: Bool
        let effects: Variable.Effects
        if let accessor = binding.accessor {
            let accessors = accessor.as(AccessorBlockSyntax.self)?.accessors

            let accessorsContainSet = accessors?.contains { $0.accessorKind.tokenKind == .contextualKeyword("set") } ?? false
            isReadOnly = !accessorsContainSet

            let getAccessor = accessors?.first { $0.accessorKind.tokenKind == .contextualKeyword("get") }
            effects = Variable.Effects(
                isThrowing: getAccessor?.throwsKeyword != nil,
                isAsync: getAccessor?.asyncKeyword != nil
            )
        } else {
            isReadOnly = false
            effects = Variable.Effects()
        }

        return VariablePart(
            identifier: identifier,
            type: WrappableType(parsing: type),
            isReadOnly: isReadOnly,
            effects: effects
        )
    }

    private struct VariablePart {
        var identifier: String
        var type: WrappableType
        var isReadOnly: Bool
        var effects: Variable.Effects
    }
}

extension Crawler {
    private func parse(_ initializer: InitializerDeclSyntax) throws -> Initializer? {
        Initializer(
            parent: container,
            attributes: attributes(from: initializer.attributes),
            accessibility: initializer.modifiers?.lazy.compactMap { Accessibility(tokenKind: $0.name.tokenKind) }.first ?? (container as? HasAccessibility)?.accessibility ?? .internal,
            signature: Method.Signature(
                genericParameters: genericParameters(from: initializer.genericParameterClause?.genericParameterList),
                parameters: try parameters(from: initializer.parameters.parameterList),
                asyncType: nil,
                throwType: initializer.throwsOrRethrowsKeyword.flatMap { ThrowType(rawValue: $0.withoutTrivia().description) },
                returnType: nil,
                whereConstraints: genericRequirements(from: initializer.genericWhereClause?.requirementList)
            ),
            isRequired: initializer.modifiers?.contains { $0.name.tokenKind == .identifier("required") } ?? false,
            isOptional: initializer.optionalMark?.isPresent == true
        )
    }
}

// MARK: - Method crawling.
extension Crawler {
    private func parse(_ method: FunctionDeclSyntax) throws -> Method? {
        // Can't mock static and final members.
        guard !method.modifiers.isStatic && !method.modifiers.isFinal else { return nil }

        guard case .identifier(let identifier) = method.identifier.tokenKind else { return nil }

        return Method(
            parent: container,
            attributes: attributes(from: method.attributes),
            accessibility: method.modifiers?.lazy.compactMap { Accessibility(tokenKind: $0.name.tokenKind) }.first ?? (container as? HasAccessibility)?.accessibility ?? .internal,
            name: identifier,
            signature: Method.Signature(
                genericParameters: genericParameters(from: method.genericParameterClause?.genericParameterList),
                parameters: try parameters(from: method.signature.input.parameterList),
                asyncType: method.signature.asyncOrReasyncKeyword.flatMap { AsyncType(rawValue: $0.withoutTrivia().description) },
                throwType: method.signature.throwsOrRethrowsKeyword.flatMap { ThrowType(rawValue: $0.withoutTrivia().description) },
                returnType: method.signature.output.map { WrappableType(parsing: $0.returnType.withoutTrivia().description) } ?? WrappableType.type("Void"),
                whereConstraints: genericRequirements(from: method.genericWhereClause?.requirementList)
            ),
            isOptional: method.modifiers?.contains { $0.name.tokenKind == .identifier("optional") } ?? false,
            isOverriding: container?.isClass ?? false
        )
    }
}

extension Crawler {
    private func parameters(from parameterList: FunctionParameterListSyntax) throws -> [MethodParameter] {
        try parameterList.map { parameter in
            guard let name = parameter.firstName?.withoutTrivia().description else { throw CrawlError.parameterNameMissing }
            guard let type = parameter.type else { throw CrawlError.parameterTypeMissing }

            let bareType: String
            let isInout: Bool
            if let attributedType = type.as(AttributedTypeSyntax.self) {
                isInout = attributedType.specifier?.tokenKind == .inoutKeyword
                bareType = attributedType.withSpecifier(nil).description
            } else {
                isInout = false
                bareType = type.description
            }

            let fullType = "\(bareType)\((parameter.ellipsis?.isPresent ?? false) ? "..." : "")"

            return MethodParameter(
                name: name,
                innerName: nil,
                type: WrappableType(parsing: fullType),
                isInout: isInout
            )
        }
    }

    private func attributes(from attributeList: AttributeListSyntax?) -> [Attribute] {
        attributeList?.children.compactMap { attribute in
            guard let attribute = attribute.as(AttributeSyntax.self) else { return nil }
            switch attribute.attributeName.tokenKind {
            case .identifier("available"):
                return .available(
                    arguments: attribute.argument?.description
                        .split(separator: ",")
                        .map { String($0).trimmed } ?? []
                )
            default:
                print("Unsupported attribute '\(attribute.attributeName.text)'")
                return nil
            }
        } ?? []
    }

    private func accessibility(from modifierList: ModifierListSyntax?) -> Accessibility? {
        modifierList?.lazy.compactMap { Accessibility(tokenKind: $0.name.tokenKind) }.first
    }

    private func genericParameters(from genericParameterList: GenericParameterListSyntax?) -> [GenericParameter] {
        genericParameterList?.map { genericParameter in
            GenericParameter(
                name: genericParameter.name.description,
                inheritedTypes: genericParameter.inheritedType.map(inheritedTypes(from:)) ?? []
            )
        } ?? []
    }

    private func genericParameters(from primaryAssociatedTypeList: PrimaryAssociatedTypeListSyntax?) -> [GenericParameter] {
        primaryAssociatedTypeList?.compactMap { associatedType in
            guard case .identifier(let identifier) = associatedType.name.tokenKind else { return nil }
            return GenericParameter(
                name: identifier,
                inheritedTypes: associatedType.inheritedType.map(inheritedTypes(from:)) ?? []
            )
        } ?? []
    }

    private func associatedTypes(from memberList: MemberDeclListSyntax) -> [GenericParameter] {
        memberList
            .compactMap { member in
                guard let associatedType = member.decl.as(AssociatedtypeDeclSyntax.self),
                      case .identifier(let identifier) = associatedType.identifier.tokenKind else { return nil }

                return GenericParameter(
                    name: identifier,
                    inheritedTypes: inheritedTypes(from: associatedType.inheritanceClause?.inheritedTypeCollection)
                )
            }
    }

    private func genericRequirements(from genericRequirementList: GenericRequirementListSyntax?) -> [String] {
        genericRequirementList?.map { $0.body.withoutTrivia().description } ?? []
    }

    private func inheritedTypes(from inheritedTypesList: InheritedTypeListSyntax?) -> [String] {
        inheritedTypesList?.flatMap { inheritedType -> [String] in
            inheritedTypes(from: inheritedType.typeName)
        } ?? []
    }

    private func inheritedTypes(from inheritedType: TypeSyntax) -> [String] {
        if let simpleType = inheritedType.as(SimpleTypeIdentifierSyntax.self) {
            return [simpleType.withoutTrivia().description]
        } else if let compositeType = inheritedType.as(CompositionTypeSyntax.self) {
            return compositeType.elements.compactMap { element in
                guard let simpleType = element.type
                    .as(SimpleTypeIdentifierSyntax.self) else {
                    return nil
                }
                return simpleType.withoutTrivia().description
            }
        } else {
            return []
        }
    }
}

extension Crawler {
    enum CrawlError: Error {
        case parameterNameMissing
        case parameterTypeMissing
    }
}

#if DEBUG
extension Crawler {
    private static let testString =
"""
class Multi {
//    @available(iOS 42.0, *)
//    var gg: Bool = false

    var asyncThrowsProperty: Int {
        get async throws { 0 }
    }
}

protocol Brek {
    var asyncThrowsProperty: Int { get async throws }
    var mutableProperty: Int { get set }

    func drak()
}
"""
}
#endif
