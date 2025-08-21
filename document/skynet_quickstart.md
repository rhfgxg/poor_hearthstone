# Skynet 快速入门指南

## 目录
1. [环境准备](#环境准备)
2. [第一个服务](#第一个服务)
3. [服务间通信](#服务间通信)
4. [常用模式](#常用模式)
5. [项目结构](#项目结构)
6. [部署运行](#部署运行)

---

## 环境准备

### 安装Skynet
```bash
git clone https://github.com/cloudwu/skynet.git
cd skynet
make linux  # Linux环境
# 或
make macosx # macOS环境
```

### 目录结构
```
skynet/
├── skynet              # 可执行文件
├── luaclib/           # C扩展库
├── lualib/            # Lua库
├── service/           # 系统服务
├── examples/          # 示例项目
└── test/              # 测试用例
```

---

## 第一个服务

### 创建主服务
创建文件 `main.lua`：

```lua
local skynet = require "skynet"

skynet.start(function()
    skynet.error("Hello Skynet!")
    
    -- 创建一个工作服务
    local worker = skynet.newservice("worker")
    
    -- 调用工作服务
    local result = skynet.call(worker, "lua", "work", "task1")
    skynet.error("Result:", result)
    
    -- 退出
    skynet.exit()
end)
```

### 创建工作服务
创建文件 `service/worker.lua`：

```lua
local skynet = require "skynet"

skynet.start(function()
    skynet.error("Worker service started")
    
    skynet.dispatch("lua", function(session, address, cmd, ...)
        if cmd == "work" then
            local task = ...
            skynet.error("Processing task:", task)
            
            -- 模拟工作
            skynet.sleep(100)  -- 1秒
            
            skynet.ret(skynet.pack("completed: " .. task))
        end
    end)
end)
```

### 配置文件
创建文件 `config.lua`：

```lua
thread = 4
start = "main"
bootstrap = "snlua bootstrap"
logger = nil
logpath = "."
```

### 运行项目
```bash
./skynet config.lua
```

---

## 服务间通信

### 基本通信模式

#### 1. 发送消息（不等待回复）
```lua
-- 发送方
skynet.send(target_service, "lua", "notify", data)

-- 接收方
skynet.dispatch("lua", function(session, address, cmd, ...)
    if cmd == "notify" then
        local data = ...
        process_notification(data)
        -- 注意：send不需要回复
    end
end)
```

#### 2. 调用服务（等待回复）
```lua
-- 调用方
local result = skynet.call(target_service, "lua", "query", params)

-- 接收方
skynet.dispatch("lua", function(session, address, cmd, ...)
    if cmd == "query" then
        local params = ...
        local result = process_query(params)
        skynet.ret(skynet.pack(result))  -- 必须回复
    end
end)
```

#### 3. 异步回复
```lua
skynet.dispatch("lua", function(session, address, cmd, ...)
    if cmd == "async_work" then
        local response = skynet.response()
        
        skynet.fork(function()
            -- 异步处理
            local result = do_async_work(...)
            response(true, result)
        end)
    end
end)
```

---

## 常用模式

### 1. 数据库服务模式
```lua
-- service/db_service.lua
local skynet = require "skynet"
local mysql = require "skynet.db.mysql"

local db

skynet.start(function()
    -- 连接数据库
    db = mysql.connect({
        host = "127.0.0.1",
        port = 3306,
        database = "gamedb",
        user = "root",
        password = "password"
    })
    
    skynet.dispatch("lua", function(session, address, cmd, ...)
        if cmd == "query" then
            local sql, params = ...
            local result = db:query(sql, params)
            skynet.ret(skynet.pack(result))
        elseif cmd == "execute" then
            local sql, params = ...
            local affected = db:query(sql, params)
            skynet.ret(skynet.pack(affected))
        end
    end)
end)
```

### 2. 玩家代理模式
```lua
-- service/player_agent.lua
local skynet = require "skynet"

skynet.start(function()
    local player_id = ...
    local player_data = {}
    
    -- 加载玩家数据
    local db_service = skynet.uniqueservice("db_service")
    local sql = "SELECT * FROM players WHERE id = ?"
    player_data = skynet.call(db_service, "lua", "query", sql, player_id)
    
    skynet.dispatch("lua", function(session, address, cmd, ...)
        if cmd == "get_info" then
            skynet.ret(skynet.pack(player_data))
        elseif cmd == "update_level" then
            local new_level = ...
            player_data.level = new_level
            
            -- 保存到数据库
            local update_sql = "UPDATE players SET level = ? WHERE id = ?"
            skynet.call(db_service, "lua", "execute", update_sql, new_level, player_id)
            
            skynet.ret(skynet.pack("ok"))
        end
    end)
end)
```

### 3. 管理器模式
```lua
-- service/player_manager.lua
local skynet = require "skynet"

local online_players = {}

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        if cmd == "login" then
            local player_id = ...
            
            if online_players[player_id] then
                skynet.ret(skynet.pack(nil, "already online"))
                return
            end
            
            -- 创建玩家代理
            local agent = skynet.newservice("player_agent", player_id)
            online_players[player_id] = agent
            
            skynet.ret(skynet.pack(agent))
            
        elseif cmd == "logout" then
            local player_id = ...
            local agent = online_players[player_id]
            
            if agent then
                skynet.kill(agent)
                online_players[player_id] = nil
            end
            
            skynet.ret(skynet.pack("ok"))
            
        elseif cmd == "get_agent" then
            local player_id = ...
            skynet.ret(skynet.pack(online_players[player_id]))
        end
    end)
end)
```

---

## 项目结构

### 推荐的项目结构
```
game_server/
├── config.lua          # 主配置文件
├── main.lua            # 入口服务
├── service/            # 业务服务
│   ├── player_agent.lua
│   ├── player_manager.lua
│   ├── db_service.lua
│   └── gate_service.lua
├── lualib/             # 业务库
│   ├── protocol.lua
│   ├── utils.lua
│   └── db_helper.lua
├── proto/              # 协议定义
├── script/             # 脚本工具
└── log/                # 日志目录
```

### 配置文件模板
```lua
-- config.lua
thread = 4                      -- 工作线程数
harbor = 0                      -- 单节点模式
start = "main"                  -- 启动服务
bootstrap = "snlua bootstrap"   -- 引导程序
logger = "logger"               -- 日志服务
logpath = "./log"              -- 日志路径
luaservice = "./service/?.lua;./skynet/service/?.lua"
lualoader = "./skynet/lualib/loader.lua"
lua_path = "./lualib/?.lua;./skynet/lualib/?.lua"
lua_cpath = "./luaclib/?.so;./skynet/luaclib/?.so"
```

### 主服务模板
```lua
-- main.lua
local skynet = require "skynet"

skynet.start(function()
    -- 启动日志服务
    skynet.uniqueservice("logger")
    
    -- 启动数据库服务
    skynet.uniqueservice("db_service")
    
    -- 启动玩家管理器
    skynet.uniqueservice("player_manager")
    
    -- 启动网关服务
    skynet.uniqueservice("gate_service")
    
    skynet.error("Game server started successfully")
    
    -- 保持主服务运行
    skynet.dispatch("lua", function() end)
end)
```

---

## 部署运行

### 开发环境
```bash
# 直接运行
./skynet config.lua

# 后台运行
nohup ./skynet config.lua &

# 查看日志
tail -f log/skynet.log
```

### 生产环境配置
```lua
-- config_prod.lua
thread = 8                      -- 增加线程数
harbor = 1                      -- 集群节点ID
daemon = "./game_server.pid"    -- 守护进程
logger = "logger"
logpath = "/var/log/gameserver"
```

### 集群部署
#### 登录服务器配置
```lua
-- login_config.lua
thread = 4
harbor = 1
cluster = "./cluster.lua"
clustername = "login"
start = "login_main"
```

#### 游戏服务器配置
```lua
-- game_config.lua
thread = 8
harbor = 2
cluster = "./cluster.lua"
clustername = "game1"
start = "game_main"
```

#### 集群配置
```lua
-- cluster.lua
return {
    login = "192.168.1.100:7001",
    game1 = "192.168.1.101:7001",
    game2 = "192.168.1.102:7001",
}
```

### 启动脚本
```bash
#!/bin/bash
# start_cluster.sh

# 启动登录服务器
ssh game@192.168.1.100 "cd /opt/gameserver && ./skynet login_config.lua"

# 启动游戏服务器
ssh game@192.168.1.101 "cd /opt/gameserver && ./skynet game1_config.lua"
ssh game@192.168.1.102 "cd /opt/gameserver && ./skynet game2_config.lua"

echo "Cluster started"
```

### 监控和维护
```lua
-- admin_service.lua - 管理服务
local skynet = require "skynet"

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        if cmd == "status" then
            local info = {
                time = skynet.time(),
                services = get_service_count(),
                memory = get_memory_usage()
            }
            skynet.ret(skynet.pack(info))
        elseif cmd == "reload" then
            local service_name = ...
            reload_service(service_name)
            skynet.ret(skynet.pack("ok"))
        end
    end)
end)
```

---

## 常见问题

### 1. 服务死锁
```lua
-- 避免循环调用
-- 服务A调用服务B，服务B又调用服务A

-- 解决方案：使用send或者重新设计架构
```

### 2. 内存泄漏
```lua
-- 及时清理不用的服务
skynet.kill(unused_service)

-- 避免在协程中创建大量临时数据
```

### 3. 性能优化
```lua
-- 批量处理而不是单个处理
-- 合理使用缓存
-- 避免频繁的跨服务调用
```

---

*快速入门指南 v1.0*  
*更新日期：2025年8月19日*
