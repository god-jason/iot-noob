--- A* Algorithm in Lua
-- @module a_star
local a_star = {}

-- 曼哈顿距离 (Heuristic)
local function manhattan(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

--- A*算法
-- @param graph 路径网络
-- @param start 起点
-- @param goal 终点
function a_star.calculate(graph, start, goal)
    local open_set = {
        [start] = true
    } -- 待搜索的节点
    local came_from = {} -- 存储路径的前驱节点
    local g_score = {} -- 从起点到当前节点的实际代价
    local f_score = {} -- 当前节点的估算代价

    -- 初始化
    g_score[start] = 0
    f_score[start] = manhattan(start, goal)

    -- 直到没有待搜索的节点
    while next(open_set) do
        -- 从待搜索集合中选择 f_score 最小的节点
        local current
        local lowest_f = math.huge
        for node, _ in pairs(open_set) do
            if f_score[node] and f_score[node] < lowest_f then
                lowest_f = f_score[node]
                current = node
            end
        end

        -- 如果目标节点被找到，构造路径
        if current == goal then
            local path = {}
            while came_from[current] do
                table.insert(path, 1, current)
                current = came_from[current]
            end
            table.insert(path, 1, start)
            return path
        end

        -- 从 open_set 中移除 current
        open_set[current] = nil

        -- 遍历相邻节点
        for _, neighbor in ipairs(graph[current]) do
            local tentative_g_score = g_score[current] + 1 -- 假设每个边的代价是 1
            if not g_score[neighbor] or tentative_g_score < g_score[neighbor] then
                -- 更新前驱节点和评分
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g_score
                f_score[neighbor] = g_score[neighbor] + manhattan(neighbor, goal)
                open_set[neighbor] = true
            end
        end
    end

    -- 如果没有找到路径，返回 nil
    return nil
end

local function test()
    -- 示例图 (网格，节点位置用坐标表示)
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

    -- 测试 A* 算法
    local start = {
        x = 1,
        y = 1
    }
    local goal = {
        x = 3,
        y = 3
    }

    -- A* 算法执行
    local path = a_star.calculate(graph, start, goal)
end

return a_star
