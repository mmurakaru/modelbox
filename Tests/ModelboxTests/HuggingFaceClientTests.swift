import XCTest
@testable import Modelbox

final class HuggingFaceClientTests: XCTestCase {
    func testRequestIncludesSearchAuthorLibraryAndSort() {
        let query = HFQuery(search: "qwen", author: "Qwen", library: "gguf", sort: .recent)
        let url = HuggingFaceClient().makeRequest(query, token: nil).url!.absoluteString
        XCTAssertTrue(url.hasPrefix("https://huggingface.co/api/models"))
        XCTAssertTrue(url.contains("search=qwen"))
        XCTAssertTrue(url.contains("author=Qwen"))
        XCTAssertTrue(url.contains("library=gguf"))
        XCTAssertTrue(url.contains("sort=lastModified"))
        XCTAssertTrue(url.contains("limit=50"))
    }

    func testRequestOmitsEmptyFilters() {
        let url = HuggingFaceClient().makeRequest(HFQuery(), token: nil).url!.absoluteString
        XCTAssertFalse(url.contains("search="))
        XCTAssertFalse(url.contains("author="))
        XCTAssertFalse(url.contains("library="))
        XCTAssertTrue(url.contains("sort=downloads"))
    }

    func testRequestSetsBearerTokenWhenPresent() {
        let request = HuggingFaceClient().makeRequest(HFQuery(search: "x"), token: "secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
    }

    func testSortApiValues() {
        XCTAssertEqual(HFSort.downloads.apiValue, "downloads")
        XCTAssertEqual(HFSort.trending.apiValue, "trendingScore")
        XCTAssertEqual(HFSort.recent.apiValue, "lastModified")
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
        XCTAssertEqual(models[1].lab, "mistralai")
        XCTAssertEqual(models[1].parameterHint, "8X7B")
    }

    func testParameterHintNilWhenAbsent() throws {
        let json = #"[{"id":"sentence-transformers/all-MiniLM-L6-v2"}]"#.data(using: .utf8)!
        let models = try JSONDecoder().decode([HFModel].self, from: json)
        XCTAssertNil(models[0].parameterHint)
    }
}
