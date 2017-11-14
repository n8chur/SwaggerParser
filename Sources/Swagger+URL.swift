import Foundation

extension Swagger {
    /// Initializes a Swagger struct using the Swagger spec at the provided URL
    /// and resolves any external references to model objects found in response 
    /// object schemas and adds them to `definitions`. This only includes
    /// references found at `paths.<path>.<method>.responses.schema.$ref.
    ///
    /// If `.json` files exist in the directory that the spec file is contained 
    /// (or any of its subfolders recusively) that are not referenced by the
    /// base spec file or any of the model files that the base spec references,
    /// ReferenceResolvingError.definitionNotFoundForFile will be thrown.
    ///
    /// This initializer can throw any errors that could be thrown by the other
    /// intiailizers as well as `ReferenceResolvingError`s.
    public init(URL url: URL) throws {
        let jsonString = try NSString(contentsOfFile: url.path, encoding: String.Encoding.utf8.rawValue) as String

        let json = try jsonString.JSON()
        
        let resolvedJSON = try json.resolvingReferences(withBaseSpecURL: url)

        let resolvedJSONString = try resolvedJSON.JSONString()
        
        try self.init(from: resolvedJSONString)
    }
}

extension Dictionary where Key == String {
    func JSONString() throws -> String {
        let data = try JSONSerialization.data(withJSONObject: self, options: [])

        guard let string = String(data: data, encoding: String.Encoding.utf8) else {
            throw DecodingError("Could not generate JSON string from JSON data")
        }

        return string
    }
}

extension String {
    func JSON() throws -> [String: Any] {
        guard let data = self.data(using: String.Encoding.utf8, allowLossyConversion: true) else {
            throw DecodingError("Could not convert JSONString into JSON")
        }

        guard let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: Any] else {
            throw DecodingError("Could not convert JSON object to [String: Any]")
        }

        return json
    }
}

