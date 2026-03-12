--- Theta* Algorithm in Lua (for 2D space)
-- @module rrt
local theta_star = {}


-- 网格地图 (0 = 可行走区域, 1 = 障碍物)
local grid = {{0, 0, 0, 0, 0, 0}, {0, 1, 1, 0, 0, 0}, {0, 0, 0, 1, 1, 0}, {0, 1, 0, 0, 0, 0}, {0, 0, 0, 1, 0, 0},
              {0, 0, 0, 0, 0, 0}}

-- 八个方向的移动 (上, 下, 左, 右, 四个对角线)
local directions = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {-1, -1}, {-1, 1}, {1, -1}, {1, 1}}

-- 判断一个点是否在网格范围内
local function in_bounds(x, y)
    return x >= 1 and y >= 1 and x <= #grid and y <= #grid[1]
end

-- 判断一个位置是否是障碍物
local function is_obstacle(x, y)
    return grid[x][y] == 1
end

-- 计算曼哈顿距离
local function manhattan_distance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

-- 计算欧几里得距离
local function euclidean_distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

-- 判断从 start 到 end 之间的路径是否没有障碍物
local function line_of_sight(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local step_x = dx > 0 and 1 or (dx < 0 and -1 or 0)
    local step_y = dy > 0 and 1 or (dy < 0 and -1 or 0)
    local dist = math.max(math.abs(dx), math.abs(dy))

    for i = 1, dist do
        local nx = math.floor(x1 + step_x * i)
        local ny = math.floor(y1 + step_y * i)
        if in_bounds(nx, ny) and is_obstacle(nx, ny) then
            return false
        end
    end
    return true
end

-- 主体函数：执行Theta*算法
function theta_star.calculate(start, goal)
    local open_list = {}
    local closed_list = {}
    local came_from = {}

    -- 启动节点的 f, g, h 值
    local function f_cost(node)
        return node.g + node.h
    end

    -- 启动节点
    table.insert(open_list, {
        x = start[1],
        y = start[2],
        g = 0,
        h = euclidean_distance(start[1], start[2], goal[1], goal[2])
    })

    -- 循环直到找到路径或没有更多节点
    while #open_list > 0 do
        -- 按 f 值排序并取出最小 f 值的节点
        table.sort(open_list, function(a, b)
            return f_cost(a) < f_cost(b)
        end)
        local current = table.remove(open_list, 1)

        -- 如果目标节点已被找到
        if current.x == goal[1] and current.y == goal[2] then
            local path = {}
            local node = current
            while node do
                table.insert(path, 1, {node.x, node.y})
                node = came_from[node.x .. "," .. node.y]
            end
            return path
        end

        -- 将当前节点加入已探索列表
        closed_list[current.x .. "," .. current.y] = true

        -- 遍历八个方向
        for _, direction in ipairs(directions) do
            local nx, ny = current.x + direction[1], current.y + direction[2]
            if in_bounds(nx, ny) and not is_obstacle(nx, ny) and not closed_list[nx .. "," .. ny] then
                -- 检查从当前节点到邻居节点的直线是否可行
                if line_of_sight(current.x, current.y, nx, ny) then
                    local tentative_g = current.g + euclidean_distance(current.x, current.y, nx, ny)
                    local neighbor = {
                        x = nx,
                        y = ny,
                        g = tentative_g,
                        h = euclidean_distance(nx, ny, goal[1], goal[2])
                    }

                    -- 如果该邻居节点未被探索或发现了更优路径
                    local add_to_open = true
                    for i, node in ipairs(open_list) do
                        if node.x == nx and node.y == ny then
                            if tentative_g < node.g then
                                open_list[i].g = tentative_g
                                open_list[i].parent = current
                            end
                            add_to_open = false
                            break
                        end
                    end

                    if add_to_open then
                        table.insert(open_list, neighbor)
                        came_from[nx .. "," .. ny] = current
                    end
                end
            end
        end
    end
    return nil -- 没有路径
end


return theta_star