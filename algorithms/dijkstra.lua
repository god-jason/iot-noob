-- Dijkstra Algorithm in Lua
-- 计算最短路径
function dijkstra(graph, start)
    local dist = {}
    local prev = {}
    local Q = {}

    -- 初始化距离
    for node in pairs(graph) do
        dist[node] = math.huge -- 设置所有节点的距离为无穷大
        prev[node] = nil -- 前驱节点为 nil
        Q[node] = true -- 设为未访问
    end

    dist[start] = 0 -- 起点到自己的距离为 0

    while next(Q) do
        -- 选择未访问的节点中距离起点最近的节点
        local minDist = math.huge
        local u = nil

        for node, _ in pairs(Q) do
            if dist[node] < minDist then
                minDist = dist[node]
                u = node
            end
        end

        if u == nil then
            break
        end -- 如果所有节点都被访问过，则结束

        -- 删除节点 u
        Q[u] = nil

        -- 更新相邻节点的距离
        for v, weight in pairs(graph[u]) do
            local alt = dist[u] + weight
            if alt < dist[v] then
                dist[v] = alt
                prev[v] = u
            end
        end
    end

    return dist, prev
end

-- 打印路径
function printPath(prev, start, target)
    local path = {}
    local node = target
    while node do
        table.insert(path, 1, node)
        node = prev[node]
    end
    if path[1] == start then
        print("Path from " .. start .. " to " .. target .. ": " .. table.concat(path, " -> "))
    else
        print("No path found.")
    end
end

-- 示例图 (邻接表形式)
local graph = {
    A = {
        B = 1,
        C = 4
    },
    B = {
        A = 1,
        C = 2,
        D = 5
    },
    C = {
        A = 4,
        B = 2,
        D = 1
    },
    D = {
        B = 5,
        C = 1
    }
}

-- 运行 Dijkstra 算法
local dist, prev = dijkstra(graph, 'A')

-- 打印从 A 到 D 的最短路径
printPath(prev, 'A', 'D')
