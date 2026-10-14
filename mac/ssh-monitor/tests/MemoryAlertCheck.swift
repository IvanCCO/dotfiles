import Foundation
@main struct MemoryAlertCheck {
    static func main() throws {
        func sample(_ ram: Double, _ swap: Double) throws -> Snapshot {
            let text = """
            {"hostname":"fedora","user":"user","system":"Linux","cpu":1,"cores":12,"memoryUsed":\(ram),"memoryTotal":15.5,"swapUsed":\(swap),"swapTotal":16,"zramUsed":5.6,"zramTotal":8,"gpu":null,"processes":[]}
            """
            return try JSONDecoder().decode(Snapshot.self, from: Data(text.utf8))
        }
        let cases: [(Double, Double, MemoryAlert)] = [(8,0,.normal), (12,0,.normal), (12.01,0,.high), (8,0.001,.swap), (13,1,.swap)]
        for (ram, swap, expected) in cases {
            let result = try sample(ram, swap)
            assert(result.memoryAlert == expected)
        }
        print("Limites de memória: 5 cenários passaram")
    }
}
