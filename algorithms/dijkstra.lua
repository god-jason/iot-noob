--- Dijkstra Algorithm in Lua
-- @module dijkstra
local dijkstra= {}

-- 计算最短路径
-- @param graph 路径网络
-- @param start 起点
function dijkstra.calculate(graph, start)
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

return dijkstra