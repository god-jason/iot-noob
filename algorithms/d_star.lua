-- D* Lite Algorithm Implementation in Lua
-- 计算曼哈顿距离（启发式函数）
local function manhattan(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

-- D* Lite 主算法
function d_star_lite(graph, start, goal)
    local open_set = {} -- 待探索的节点集合（开放集合）
    local g_score = {} -- 从起点到某节点的代价
    local rhs = {} -- 从目标到某节点的代价（反向估算）
    local parent = {} -- 节点的前驱节点

    -- 初始化 g_score 和 rhs
    for node, _ in pairs(graph) do
        g_score[node] = math.huge
        rhs[node] = math.huge
        parent[node] = nil
    end
    rhs[goal] = 0 -- 目标节点的估算代价为 0
    g_score[start] = math.huge -- 起点初始化为无穷大

    -- 插入目标节点到开放集合中
    table.insert(open_set, goal)

    -- 更新节点函数
    local function update_node(u)
        local min_rhs = math.huge
        for _, neighbor in ipairs(graph[u]) do
            local new_rhs = g_score[neighbor] + 1 -- 假设每个边的代价为 1
            if new_rhs < min_rhs then
                min_rhs = new_rhs
                parent[u] = neighbor
            end
        end
        rhs[u] = min_rhs
    end

    -- 主循环
    while #open_set > 0 do
        -- 获取当前代价最小的节点
        table.sort(open_set, function(a, b)
            return g_score[a] < g_score[b]
        end)
        local current = open_set[1]

        if g_score[current] <= rhs[current] then
            -- 如果当前节点的代价小于等于 rhs 值，进行路径更新
            update_node(current)
            table.remove(open_set, 1)
        else
            -- 否则，我们通过在开放集合中更新路径
            g_score[current] = rhs[current]
            table.remove(open_set, 1)
        end

        -- 如果找到目标节点，构造路径
        if current == start then
            local path = {}
            local node = start
            while node do
                table.insert(path, 1, node)
                node = parent[node]
            end
            return path
        end
    end

    return nil
end

-- 示例图（邻接表表示法）
local graph = {{{
    x = 1,
    y = 1
}, {
    x = 2,
    y = 1
}, {
    x = 3,
    y = 1
}}, {{
    x = 1,
    y = 2
}, {
    x = 2,
    y = 2
}, {
    x = 3,
    y = 2
}}, {{
    x = 1,
    y = 3
}, {
    x = 2,
    y = 3
}, {
    x = 3,
    y = 3
}}}

-- 测试 D* 算法
local start = {
    x = 1,
    y = 1
}
local goal = {
    x = 3,
    y = 3
}

-- D* 算法执行
local path = d_star_lite(graph, start, goal)

if path then
    print("Path found:")
    for _, node in ipairs(path) do
        print("(", node.x, ",", node.y, ")")
    end
else
    print("No path found.")
end
