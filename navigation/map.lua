-- 地图类
local Map = {}
Map.__index = Map

-- 创建一个新的地图实例
function Map:new(width, height)
    local map = {}
    setmetatable(map, Map)

    -- 地图的宽度和高度
    map.width = width
    map.height = height

    -- 障碍物集合（初始化为空）
    map.obstacles = {}

    -- 地图上每个点的状态（默认都是可通行的）
    map.grid = {}
    for x = 1, width do
        map.grid[x] = {}
        for y = 1, height do
            map.grid[x][y] = 0  -- 0代表可通行，1代表障碍物
        end
    end

    return map
end

-- 设置障碍物（标记位置为1）
function Map:set_obstacle(x, y)
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
        self.grid[x][y] = 1
        table.insert(self.obstacles, {x = x, y = y})
    end
end

-- 检查某个位置是否为障碍物
function Map:is_obstacle(x, y)
    return self.grid[x] and self.grid[x][y] == 1
end

-- 计算两点之间的曼哈顿距离（用于路径规划）
function Map:manhattan_distance(x1, y1, x2, y2)
    return math.abs(x2 - x1) + math.abs(y2 - y1)
end

-- 获取某个点的邻居（上下左右）
function Map:get_neighbors(x, y)
    local neighbors = {}
    if x > 1 then table.insert(neighbors, {x = x - 1, y = y}) end
    if x < self.width then table.insert(neighbors, {x = x + 1, y = y}) end
    if y > 1 then table.insert(neighbors, {x = x, y = y - 1}) end
    if y < self.height then table.insert(neighbors, {x = x, y = y + 1}) end
    return neighbors
end

-- 打印地图（可视化）
function Map:print_map()
    for y = 1, self.height do
        local row = ""
        for x = 1, self.width do
            if self:is_obstacle(x, y) then
                row = row .. " # "
            else
                row = row .. " . "
            end
        end
        print(row)
    end
end

-- 将地图转化为文本
function Map:map_to_text()
    local text = ""
    for y = 1, self.height do
        local row = ""
        for x = 1, self.width do
            if self:is_obstacle(x, y) then
                row = row .. "#"
            else
                row = row .. "."
            end
        end
        text = text .. row .. "\n"
    end
    return text
end

-- 从文本恢复地图
function Map:text_to_map(text)
    local lines = {}
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local new_map = Map:new(#lines[1], #lines)

    for y, line in ipairs(lines) do
        for x = 1, #line do
            if line:sub(x, x) == "#" then
                new_map:set_obstacle(x, y)
            end
        end
    end

    return new_map
end


return Map