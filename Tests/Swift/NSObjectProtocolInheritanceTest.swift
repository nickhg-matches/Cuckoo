import XCTest

class NSObjectProtocolTest: XCTestCase {

    private var mockProtocolNotInheritingFromNSObjectProtocol: MockProtocolNotInheritingFromNSObjectProtocol!

    override func setUp() {
        super.setUp()

        mockProtocolNotInheritingFromNSObjectProtocol = MockProtocolNotInheritingFromNSObjectProtocol()
    }

    func testProtocolNotInheritingFromNSObjectProtocol() {
        XCTAssert(!(mockProtocolNotInheritingFromNSObjectProtocol is NSObject))
    }
}
