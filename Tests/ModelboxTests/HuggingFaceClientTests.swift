import XCTest
@testable import Modelbox

final class HuggingFaceClientTests: XCTestCase {
    func testRequestIncludesSearchAndDefaults() {
        let request = HuggingFaceClient().makeRequest(query: "qwen", token: nil)
        let url = request.url!.absoluteString
        XCTAssertTrue(url.hasPrefix("https://huggingface.co/api/models"))
        XCTAssertTrue(url.contains("search=qwen"))
        XCTAssertTrue(url.contains("limit=50"))
        XCTAssertTrue(url.contains("sort=downloads"))
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testRequestOmitsSearchWhenQueryBlank() {
        let request = HuggingFaceClient().makeRequest(query: "   ", token: nil)
        XCTAssertFalse(request.url!.absoluteString.contains("search="))
    }

    func testRequestSetsBearerTokenWhenPresent() {
        let request = HuggingFaceClient().makeRequest(query: "x", token: "secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
    }

    func testDecodesListIgnoringUnknownFields() throws {
        let json = """
        [
          {"_id":"abc","id":"Qwen/Qwen3-8B","likes":10,"downloads":12345,
           "pipeline_tag":"text-generation","library_name":"transformers","tags":["x"]},
          {"_id":"def","id":"mistralai/Mixtral-8x7B-Instruct-v0.1","downloads":999}
        ]
        """.data(using: .utf8)!

        let models = try JSONDecoder().decode([HFModel].self, from: json)
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models[0].lab, "Qwen")
        XCTAssertEqual(models[0].name, "Qwen3-8B")
        XCTAssertEqual(models[0].parameterHint, "8B")
        XCTAssertEqual(models[0].pipelineTag, "text-generation")
        XCTAssertEqual(models[1].lab, "mistralai")
        XCTAssertEqual(models[1].parameterHint, "8X7B")
    }

    func testParameterHintNilWhenAbsent() throws {
        let json = #"[{"id":"sentence-transformers/all-MiniLM-L6-v2"}]"#.data(using: .utf8)!
        let models = try JSONDecoder().decode([HFModel].self, from: json)
        XCTAssertNil(models[0].parameterHint)
    }
}
