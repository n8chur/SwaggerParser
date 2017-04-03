import ObjectMapper

/// Schemas are used to define the types used in body parameters. They are more expressive than Items.
public enum Schema {
    indirect case object(ObjectSchema)
    indirect case array(ArraySchema)
    case string(metadata: Metadata, format: StringFormat?)
    case number(metadata: Metadata, format: NumberFormat?)
    case integer(metadata: Metadata, format: IntegerFormat?)
    case enumeration(metadata: Metadata)
    case boolean(metadata: Metadata)
}

enum SchemaBuilder: Builder {

    typealias Building = Schema

    indirect case object(ObjectSchemaBuilder)
    indirect case array(ArraySchemaBuilder)
    indirect case pointer(Pointer<SchemaBuilder>)
    case string(metadata: MetadataBuilder, format: StringFormat?)
    case number(metadata: MetadataBuilder, format: NumberFormat?)
    case integer(metadata: MetadataBuilder, format: IntegerFormat?)
    case enumeration(metadata: MetadataBuilder)
    case boolean(metadata: MetadataBuilder)

    public init(map: Map) throws {
        // Check if a reference
        if let pointer = try? Pointer<SchemaBuilder>(map: map) {
            self = .pointer(pointer)
            return
        }

        // Map according to the type:
        let metadata = try MetadataBuilder(map: map)
        switch metadata.type {
        case .object:
            self = .object(try ObjectSchemaBuilder(map: map))
        case .array:
            self = .array(try ArraySchemaBuilder(map: map))
        case .string:
            self = .string(metadata: metadata, format: try? map.value("format"))
        case .number:
            self = .number(metadata: metadata, format: try? map.value("format"))
        case .integer:
            self = .integer(metadata: metadata, format: try? map.value("format"))
        case .enumeration:
            self = .enumeration(metadata: metadata)
        case .boolean:
            self = .boolean(metadata: metadata)
        }
    }

    func build(_ swagger: SwaggerBuilder) throws -> Schema {
        switch self {
        case .object(let builder):
            return .object(try builder.build(swagger))
        case .array(let builder):
            return .array(try builder.build(swagger))
        case .pointer(let pointer):
            return try SchemaBuilder.resolve(swagger, pointer: pointer)
        case .string(let metadataBuilder, let format):
            return .string(metadata: try metadataBuilder.build(swagger), format: format)
        case .number(let metadataBuilder, let format):
            return .number(metadata: try metadataBuilder.build(swagger), format: format)
        case .integer(let metadataBuilder, let format):
            return .integer(metadata: try metadataBuilder.build(swagger), format: format)
        case .enumeration(let metadataBuilder):
            return .enumeration(metadata: try metadataBuilder.build(swagger))
        case .boolean(let metadataBuilder):
            return .boolean(metadata: try metadataBuilder.build(swagger))
        }
    }
}

extension SchemaBuilder {
    static func resolve(_ swagger: SwaggerBuilder, pointer: Pointer<SchemaBuilder>) throws -> Schema {
        let components = pointer.path.components(separatedBy: "/")
        if components.count == 3 && components[0] == "#" && components[1] == "definitions",
            let builder = swagger.definitions[components[2]]
        {
            return try builder.build(swagger)
        } else {
            throw DecodingError()
        }
    }
}