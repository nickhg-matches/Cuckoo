protocol ContainerToken: Token, HasAttributes, HasAccessibility, HasName, HasGenerics, HasMembers, HasInheritance {}

extension ContainerToken {
    func containerSerialize() -> GeneratorContext {
        func withAdjustedAccessibility<TokenType: HasAccessibility>(token: TokenType) -> TokenType {
            // We only want to adjust tokens that are accessible and lower than the enclosing type
            guard token.accessibility.isAccessible && token.accessibility < accessibility else { return token }
            var mutableToken = token
            mutableToken.accessibility = accessibility
            return mutableToken
        }

        let accessibilityAdjustedMembers = members.map { child -> Token in
            guard let memberWithAccessibility = child as? Token & HasAccessibility else { return child }
            return withAdjustedAccessibility(token: memberWithAccessibility)
        }

        let properties = accessibilityAdjustedMembers.compactMap { $0 as? Variable }
            .filter { $0.accessibility.isAccessible }
            .map { $0.serialize() }

        let methods = accessibilityAdjustedMembers.compactMap { $0 as? Method }
            .filter { $0.accessibility.isAccessible }
            .map { $0.serialize() }

        let initializers = accessibilityAdjustedMembers.compactMap { $0 as? Initializer }
            .filter { $0.accessibility.isAccessible }
            .map { $0.serialize() }

        return [
            "accessibility": accessibility.sourceName,
//            "isAccessible": accessibility.isAccessible,
//            "children": accessibilityAdjustedMembers.map { $0.serialize() },
            "properties": properties,
            "initializers": isClass ? [] : initializers,
            "methods": methods,
            "attributes": attributes,
        ]
        .compactMapValues { $0 }
    }
}
