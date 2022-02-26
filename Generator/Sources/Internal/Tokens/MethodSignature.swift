import Foundation

extension Method {
    struct Signature {
        let genericParameters: [GenericParameter]
        let parameters: [MethodParameter]
        let asyncType: AsyncType?
        let throwType: ThrowType?
        let returnType: WrappableType?
        let whereConstraints: [String]

        init(
            genericParameters: [GenericParameter],
            parameters: [MethodParameter],
            asyncType: AsyncType? = nil,
            throwType: ThrowType? = nil,
            returnType: WrappableType? = nil,
            whereConstraints: [String]
        ) {
            self.genericParameters = genericParameters
            self.parameters = parameters.enumerated().map { index, parameter in
                MethodParameter(
                    parent: parameter.parent,
                    name: parameter.name,
                    innerName: "p\(index)",
                    type: parameter.type,
                    isInout: parameter.isInout
                )
            }
            self.asyncType = asyncType
            self.throwType = throwType
            self.returnType = returnType
            self.whereConstraints = whereConstraints
        }

        var description: String {
            let genericParametersString = genericParameters.map { $0.description }.joined(separator: ", ")
            let returnString: String?
            if let returnType {
                let trimmedReturnType = returnType.explicitOptionalOnly.sugarized.trimmed
                let returnsVoid = trimmedReturnType.isEmpty || trimmedReturnType == "Void"
                returnString = returnsVoid ? nil : "-> \(returnType)"
            } else {
                returnString = nil
            }
            let whereString = whereConstraints.isEmpty ? nil : "where \(whereConstraints.joined(separator: ", "))"
            return [
                genericParametersString.isEmpty ? nil : "<\(genericParametersString)>",
                "(\(parameters.map { $0.description }.joined(separator: ", ")))",
                asyncType?.description,
                throwType?.description,
                returnString,
                whereString,
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        }
    }
}

extension Method.Signature {
    func isApiEqual(to other: Method.Signature) -> Bool {
        genericParameters == other.genericParameters
        && parameters.elementsEqual(other.parameters) { $0.name == $1.name && $0.type == $1.type }
        && asyncType == other.asyncType
        && throwType == other.throwType
        && returnType == other.returnType
        && whereConstraints == other.whereConstraints
    }
}
