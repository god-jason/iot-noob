-- RRT Algorithm in Lua (for 2D space)
-- 随机生成一个点
local function random_point()
    return {
        x = math.random(1, 100),
        y = math.random(1, 100)
    }
end

-- 计算两个点之间的欧氏距离
local function distance(p1, p2)
    return math.sqrt((p1.x - p2.x) ^ 2 + (p1.y - p2.y) ^ 2)
end

-- 从点 A 向点 B 移动，并确保不会超出最大步长
local function move_toward(A, B, max_step)
    local dist = distance(A, B)
    if dist < max_step then
        return B
    else
        local ratio = max_step / dist
        return {
            x = A.x + ratio * (B.x - A.x),
            y = A.y + ratio * (B.y - A.y)
        }
    end
end

-- 检查两点之间的路径是否与障碍物碰撞
local function check_collision(p1, p2, obstacles)
    -- 这里假设没有障碍物，只是一个简单的示例
    -- 实际情况需要对路径进行碰撞检测
    return false
end

-- RRT 算法实现
function rrt(start, goal, max_steps, max_step_length, obstacles)
    local tree = {start} -- 初始化树，从起点开始
    local parents = {
        [start] = nil
    } -- 保存树中的父节点

    for i = 1, max_steps do
        -- 随机生成一个目标点
        local rand_point = random_point()

        -- 找到树中离随机点最近的节点
        local nearest_node = nil
        local min_dist = math.huge
        for _, node in ipairs(tree) do
            local dist = distance(node, rand_point)
            if dist < min_dist then
                min_dist = dist
                nearest_node = node
            end
        end

        -- 将树扩展到随机点
        local new_node = move_toward(nearest_node, rand_point, max_step_length)

        -- 检查从 nearest_node 到 new_node 是否发生碰撞
        if not check_collision(nearest_node, new_node, obstacles) then
            table.insert(tree, new_node)
            parents[new_node] = nearest_node

            -- 如果新节点接近目标节点，则连接目标并返回路径
            if distance(new_node, goal) < max_step_length then
                table.insert(tree, goal)
                parents[goal] = new_node
                -- 构建路径
                local path = {}
                local current = goal
                while current do
                    table.insert(path, 1, current)
                    current = parents[current]
                end
                return path
            end
        end
    end

    return nil -- 未找到路径
end

-- 可视化路径（简单打印路径）
function print_path(path)
    if path then
        for _, point in ipairs(path) do
            print("(", point.x, ",", point.y, ")")
        end
    else
        print("No path found.")
    end
end

-- 示例起点和目标点
local start = {
    x = 1,
    y = 1
}
local goal = {
    x = 90,
    y = 90
}

-- 运行 RRT 算法
local path = rrt(start, goal, 1000, 5)

-- 打印路径
print_path(path)
