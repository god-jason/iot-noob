local points = {}

-- 数据点类型
points.feagure = {
    bool = { byte = 1, word = 1, pack = "b" },
    boolean = { byte = 1, word = 1, pack = "b" }, --按位去读
    char = { byte = 1, word = 1, pack = "c" },
    byte = { byte = 1, word = 1, pack = "b" },
    int8 = { byte = 1, word = 1, pack = "c" },
    uint8 = { byte = 1, word = 1, pack = "b" },
    short = { byte = 2, word = 1, pack = "h" },
    word = { byte = 2, word = 1, pack = "H" },
    int16 = { byte = 2, word = 1, pack = "h" },
    uint16 = { byte = 2, word = 1, pack = "H" },
    qword = { byte = 4, word = 2, pack = "I" },
    int = { byte = 4, word = 2, pack = "i" },
    uint = { byte = 4, word = 2, pack = "I" },
    int32 = { byte = 4, word = 2, pack = "i" },
    uint32 = { byte = 4, word = 2, pack = "I" },
    float = { byte = 4, word = 2, pack = "f" },
    float32 = { byte = 4, word = 2, pack = "f" },
    double = { byte = 8, word = 4, pack = "d" },
    float64 = { byte = 8, word = 4, pack = "d" }
}

return points
