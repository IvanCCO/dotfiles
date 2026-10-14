import Foundation
@main struct MemoryAlertCheck {
    static func main() throws {
        func sample(_ ram: Double, _ swap: Double, total: Double = 16) throws -> Snapshot {
            let text = """
            {"hostname":"test","user":"user","system":"Linux","cpu":1,"cores":12,"memoryUsed":\(ram),"memoryTotal":10,"swapUsed":\(swap),"swapTotal":\(total),"zramUsed":5.6,"zramTotal":8,"gpu":null,"processes":[]}
            """
            return try JSONDecoder().decode(Snapshot.self, from: Data(text.utf8))
        }
        let cases: [(Double, Double, MemoryAlert)] = [
            (5,2,.normal), (6.99,0,.normal), (7,0,.warning),
            (5,11.2,.warning), (8,0,.warning), (8,12.8,.critical),
            (9,0,.critical), (5,16,.warning), (8,2,.warning)
        ]
        for (ram, swap, expected) in cases {
            let result = try sample(ram, swap)
            assert(result.memoryAlert == expected)
        }
        let noSwap = try sample(5, 0, total: 0)
        assert(noSwap.memoryAlert == .normal)
        var filter = MemoryAlertFilter()
        filter.update(.warning, at: 0)
        filter.update(.warning, at: 9)
        assert(filter.current == .normal)
        filter.update(.warning, at: 10)
        assert(filter.current == .warning)
        filter.update(.critical, at: 11)
        filter.update(.normal, at: 12)
        filter.update(.critical, at: 13)
        filter.update(.critical, at: 22)
        assert(filter.current == .warning)
        filter.update(.critical, at: 23)
        assert(filter.current == .critical)
        filter.update(.normal, at: 24)
        filter.update(.normal, at: 34)
        assert(filter.current == .normal)
        print("10 cenários de memória e transições de 10 segundos passaram")
    }
}
