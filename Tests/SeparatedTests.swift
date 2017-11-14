import XCTest
@testable import SwaggerParser

class SeparatedTests: XCTestCase {
    func testSeparated() {
        let url = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("Separated")
            .appendingPathComponent("test.json")
        let swagger = try! Swagger(URL: url)
        XCTAssertEqual(swagger.host?.absoluteString, "api.test.com")

        XCTAssertEqual(swagger.definitions.count, 5)

        let parentName = "parent"
        let parentPropertyNames = ["type"]

        guard let parentDefinition = swagger.definitions[parentName],
            case .object(let parent) = parentDefinition.type else {
                XCTFail("child is not an object."); return
        }
        SeparatedTests.validate(thatSchema: parent, named: parentName, hasRequiredProperties: parentPropertyNames)

        let childName = "child"
        let childPropertyNames = ["reference"]

        guard let childSchema = swagger.definitions[childName] else {
            XCTFail("child schema not found."); return
        }

        SeparatedTests.validate(
            thatChildSchema: childSchema,
            named: childName,
            withProperties: childPropertyNames,
            hasParentNamed: parentName,
            withProperties: parentPropertyNames)

        guard
            let either = swagger.paths["/test"]?.operations[.get]?.responses[200],
            case .a(let response) = either else {
                XCTFail("response not found for GET /test 200."); return
        }
        guard
            let responseSchema = response.schema,
            case .structure(let responseSchemaStructure) = responseSchema.type else {
                XCTFail("response schema is not a structure."); return
        }
        XCTAssertEqual(responseSchemaStructure.name, childName)

        guard let responseChildSchema = responseSchemaStructure.structure else {
            XCTFail("response child schema is not resolved."); return
        }

        SeparatedTests.validate(
            thatChildSchema: responseChildSchema,
            named: childName,
            withProperties: childPropertyNames,
            hasParentNamed: parentName,
            withProperties: parentPropertyNames)

        guard case .object(let definitionRef) = swagger.definitions["definitions-reference"]!.type else {
            XCTFail("`definitions-reference` is not an object."); return
        }
        XCTAssertNotNil(definitionRef.properties.first(where: {$0.key == "bar"})?.value)

        guard case .allOf(let allOf) = responseChildSchema.type else {
            XCTFail("Response schema is not an .allOf"); return
        }
        XCTAssertEqual(allOf.subschemas.count, 2)

        guard
            let childAllOfSchema = allOf.subschemas.last,
            case .object(let child) = childAllOfSchema.type else {
                XCTFail("Response schema's .allOf's last item is not an .object"); return
        }

        guard let referenceProperty = child.properties.first(where: {$0.key == "reference"})?.value else {
            XCTFail("Response schema's .allOf's last item does not have a 'reference' property."); return
        }

        guard
            case .structure(let referenceStructure) = referenceProperty.type,
            referenceStructure.name == "reference",
            case .object(let reference) = referenceStructure.structure.type else {
                XCTFail("Response schema's .allOf's last item's 'reference' property is not a Structure<Schema.object>."); return
        }

        guard
            let arrayProperty = reference.properties.first(where: {$0.key == "array-items"})?.value,
            case .array(let arraySchema) = arrayProperty.type,
            case .one(let arrayItemSchema) = arraySchema.items else {
                XCTFail("Array property not found on reference."); return
        }

        guard
            case .structure(let arrayStructure) = arrayItemSchema.type,
            arrayStructure.name == "array-item",
            case .object(let arrayItemObjectSchema) = arrayStructure.structure.type else {
                XCTFail("`array-items` poprety does not contain an object reference."); return
        }

        XCTAssertNotNil(arrayItemObjectSchema.properties.first(where: {$0.key == "foo"})?.value)
    }
}

/// MARK: Validation functions

fileprivate extension SeparatedTests {
    class func validate(thatSchema schema: ObjectSchema, named name: String, hasRequiredProperties properties: [String]) {
        XCTAssertEqual(schema.properties.count, properties.count)
        XCTAssertEqual(schema.required, properties)
        
        properties.forEach { property in
            XCTAssertNotNil(schema.properties.first(where: {$0.key == property}))
        }
    }

    class func validate(thatChildSchema childSchema: Schema, named childName: String, withProperties childProperties: [String], hasParentNamed parentName: String, withProperties parentProperties: [String]) {
        guard case .allOf(let childAllOf) = childSchema.type else {
            XCTFail("\(childName) is not an allOf."); return
        }
        XCTAssertEqual(childAllOf.subschemas.count, 2)
        
        guard
            let childsParent = childAllOf.subschemas.first,
            case .structure(let childsParentStructure) = childsParent.type,
            childsParentStructure.name == parentName,
            case .object(let childsParentSchema) = childsParentStructure.structure.type else {
                XCTFail("\(childName)'s parent is not a Structure<Schema.object>"); return
        }
        SeparatedTests.validate(thatSchema: childsParentSchema, named: parentName, hasRequiredProperties: parentProperties)
        
        guard let discriminator = childsParentSchema.metadata.discriminator else {
            XCTFail("\(parentName) has no discriminator."); return
        }
        XCTAssertTrue(parentProperties.contains(discriminator))
        
        guard
            let child = childAllOf.subschemas.last,
            case .object(let childSchema) = child.type else {
                XCTFail("child is not a Structure<Schema.object>"); return
        }
        SeparatedTests.validate(thatSchema: childSchema, named: childName, hasRequiredProperties: childProperties)
    }
}

