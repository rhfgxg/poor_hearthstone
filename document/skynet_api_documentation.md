# Skynet 框架 API 文档

## 目录
1. [框架简介](#框架简介)
2. [核心API](#核心api)
3. [服务管理](#服务管理)
4. [消息传递](#消息传递)
5. [定时器](#定时器)
6. [数据库操作](#数据库操作)
7. [网络相关](#网络相关)
8. [集群管理](#集群管理)
9. [配置管理](#配置管理)
10. [调试工具](#调试工具)

---

## 框架简介

Skynet 是一个轻量级的分布式游戏服务器框架，使用 C + Lua 开发。它采用 Actor 模型，每个服务都是独立的 Actor，通过消息传递进行通信。

### 特点
- 轻量级，高性能
- 基于消息传递的并发模型
- 支持热更新
- 内置集群支持
- 简单易用的API

---

## 核心API

### skynet.start(func)
启动服务的主入口函数。

```lua
skynet.start(function()
    -- 服务初始化代码
    skynet.dispatch("lua", function(session, address, cmd, ...)
        -- 处理消息
    end)
end)
```

### skynet.exit()
退出当前服务。

```lua
skynet.exit()
```

### skynet.error(msg, ...)
输出错误日志。

```lua
skynet.error("Error message: %s", error_info)
```

### skynet.getenv(key)
获取环境变量。

```lua
local thread_count = skynet.getenv("thread")
```

### skynet.setenv(key, value)
设置环境变量。

```lua
skynet.setenv("daemon", "./skynet.pid")
```

---

## 服务管理

### skynet.newservice(name, ...)
创建新服务实例。

**功能说明：**
每次调用都会创建一个全新的服务实例，即使服务名相同，也会创建多个独立的服务。

**参数详解：**
- `name` (string): 服务脚本名称，对应 `service/` 目录下的 `.lua` 文件
- `...` (任意类型): 传递给服务初始化函数的参数

**返回值：**
- 返回新创建服务的地址ID（整数），用于后续的消息通信

**使用示例：**
```lua
-- 创建多个相同的服务实例
local service1 = skynet.newservice("worker", "task1", {priority = 1})
local service2 = skynet.newservice("worker", "task2", {priority = 2})
local service3 = skynet.newservice("worker", "task3", {priority = 3})

-- 三个服务虽然名称相同，但是完全独立的实例
skynet.error("Service1 ID:", service1)  -- 输出：Service1 ID: 16777216
skynet.error("Service2 ID:", service2)  -- 输出：Service2 ID: 16777217  
skynet.error("Service3 ID:", service3)  -- 输出：Service3 ID: 16777218
```

### skynet.uniqueservice(name, ...)
创建或获取唯一服务（单例模式）。

**功能说明：**
确保整个Skynet节点中只存在一个指定名称的服务实例。如果服务已存在，返回现有服务的地址；如果不存在，则创建新服务。

**参数详解：**
- `name` (string): 唯一服务的名称标识
- `...` (任意类型): 仅在首次创建时传递给服务的初始化参数

**返回值：**
- 返回唯一服务的地址ID，多次调用返回相同的地址

**使用示例：**
```lua
-- 第一次调用，创建新的唯一服务
local db_service1 = skynet.uniqueservice("database", "mysql://localhost:3306")
skynet.error("First call ID:", db_service1)  -- 输出：First call ID: 16777220

-- 第二次调用，返回已存在的服务
local db_service2 = skynet.uniqueservice("database", "other_params")  -- other_params被忽略
skynet.error("Second call ID:", db_service2)  -- 输出：Second call ID: 16777220

-- 两次调用返回相同的服务地址
assert(db_service1 == db_service2)  -- true
```

**区别对比表格：**

| 特性 | skynet.newservice | skynet.uniqueservice |
|------|-------------------|----------------------|
| **实例数量** | 每次调用创建新实例 | 全节点唯一实例 |
| **返回值** | 每次都是新的地址ID | 相同名称返回相同ID |
| **参数传递** | 每次调用都会传递参数 | 只有首次创建时传递参数 |
| **使用场景** | 工作进程、任务处理器 | 数据库连接、配置管理 |
| **资源消耗** | 多实例消耗更多资源 | 单实例节省资源 |
| **并发处理** | 多实例可并行处理 | 单实例串行处理 |
| **作用范围** | **单个Skynet节点内** | **单个Skynet节点内** |

**❗ 重要澄清：单服务器 vs 分布式服务器概念**

很多初学者会混淆这两个概念，让我们明确区分：

### 🖥️ **服务器架构层面（物理部署）**
- **单服务器**：整个游戏运行在一台物理服务器上
- **分布式服务器**：游戏服务分布在多台物理服务器上

### 🔧 **Skynet服务层面（进程内）**
- **newservice**：在同一个Skynet节点内创建多个服务实例
- **uniqueservice**：在同一个Skynet节点内创建唯一服务实例

**关键理解：**
```
❌ 错误理解：
uniqueservice = 单服务器架构
newservice = 分布式服务器架构

✅ 正确理解：
uniqueservice = 同一节点内的单例服务
newservice = 同一节点内的多实例服务

这两个API都是在单个Skynet节点内操作，与分布式部署无关！
```

### 🌐 **Skynet的分布式支持**

Skynet的分布式是通过**集群(Cluster)**功能实现的，不是通过 newservice/uniqueservice：

```lua
-- === 分布式相关的API是这些 ===
local cluster = require "skynet.cluster"

-- 连接到其他物理服务器节点
cluster.open("server_node_2")

-- 调用其他服务器节点上的服务
local result = cluster.call("server_node_2", "player_manager", "get_player", player_id)

-- 在其他服务器节点创建服务
cluster.send("server_node_2", ".launcher", "LAUNCH", "service", "new_service_name")
```

### 📊 **完整架构示例**

```lua
-- === 单个Skynet节点内的服务管理 ===
-- 服务器A (192.168.1.100)
skynet.start(function()
    -- 创建多个玩家代理服务（同一节点内多实例）
    local player1_agent = skynet.newservice("player_agent", player1_id)
    local player2_agent = skynet.newservice("player_agent", player2_id)
    
    -- 创建唯一的数据库管理器（同一节点内单例）
    local db_manager = skynet.uniqueservice("db_manager")
    
    -- 上面的服务都运行在同一个物理服务器的同一个Skynet进程中
end)

-- === 分布式集群间的服务通信 ===
-- 服务器A调用服务器B的服务
local cluster = require "skynet.cluster"

-- 连接到服务器B
cluster.open("server_b")

-- 调用服务器B上的服务
local result = cluster.call("server_b", "battle_manager", "start_battle", battle_data)
```

### 🏗️ **实际分布式架构设计**

```
物理架构：
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   登录服务器     │    │   游戏服务器1    │    │   游戏服务器2    │
│ (192.168.1.100) │    │ (192.168.1.101) │    │ (192.168.1.102) │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ Skynet节点A     │    │ Skynet节点B     │    │ Skynet节点C     │
│                 │    │                 │    │                 │
│ uniqueservice:  │    │ uniqueservice:  │    │ uniqueservice:  │
│ - login_mgr     │    │ - world_mgr     │    │ - battle_mgr    │
│                 │    │                 │    │                 │
│ newservice:     │    │ newservice:     │    │ newservice:     │
│ - auth_worker×3 │    │ - player_agent×N│    │ - battle_room×M │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                        cluster.call() 通信
```

### 🎯 **使用场景总结**

1. **在单个节点内使用 newservice/uniqueservice：**
   ```lua
   -- 处理大量玩家请求 - 使用多实例并行处理
   for i = 1, 10 do
       local worker = skynet.newservice("request_handler", i)
   end
   
   -- 管理全局配置 - 使用单例避免数据不一致
   local config_mgr = skynet.uniqueservice("config_manager")
   ```

2. **在多个节点间使用 cluster：**
   ```lua
   -- 跨服务器通信
   local result = cluster.call("game_server_2", "player_manager", "transfer_player", player_data)
   ```

**实际应用场景：**

```lua
-- 适合使用 newservice 的场景：
-- 1. 游戏中的玩家代理服务（每个玩家一个实例）
local player_agent = skynet.newservice("player_agent", player_id, player_data)

-- 2. 任务处理器（可以并行处理多个任务）
for i = 1, 10 do
    local worker = skynet.newservice("task_worker", i)
    skynet.send(worker, "lua", "process_task", task_data)
end

-- 适合使用 uniqueservice 的场景：
-- 1. 数据库连接管理器（全局唯一）
local db_mgr = skynet.uniqueservice("db_manager")

-- 2. 配置管理服务（全局配置）
local config_mgr = skynet.uniqueservice("config_manager")

-- 3. 日志服务（统一日志处理）
local logger = skynet.uniqueservice("logger")
```

---

## 🌐 Skynet分布式架构详解

### ❗ 重要概念澄清

很多初学者会混淆这些概念，让我详细说明：

**❌ 错误理解：**
- `uniqueservice` = 单服务器架构  
- `newservice` = 分布式服务器架构

**✅ 正确理解：**
- `uniqueservice` = 单个Skynet节点内的唯一实例
- `newservice` = 单个Skynet节点内的多个实例
- **这两个API都是在单个Skynet节点内操作，与分布式部署无关！**

### 分布式概念的三个层次

#### 1️⃣ **进程内服务层 (newservice/uniqueservice)**

```
单个Skynet进程内部：
┌─────────────────────────────────┐
│        Skynet节点进程            │
│  ┌─────────┐ ┌─────────┐       │
│  │ Service │ │ Service │ ...   │ <- newservice创建
│  │    A    │ │    B    │       │
│  └─────────┘ └─────────┘       │
│  ┌─────────────────────┐       │
│  │   Unique Service    │       │ <- uniqueservice创建
│  │     Manager         │       │
│  └─────────────────────┘       │
└─────────────────────────────────┘
```

#### 2️⃣ **集群节点层 (cluster)**

```
多个Skynet节点组成集群：
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  节点A       │    │  节点B       │    │  节点C       │
│ (登录服务器)  │────│ (游戏服务器1) │────│ (游戏服务器2) │
│ 192.168.1.1 │    │ 192.168.1.2 │    │ 192.168.1.3 │
└─────────────┘    └─────────────┘    └─────────────┘
        │                   │                   │
        └─────── cluster.call() 通信 ──────────┘
```

#### 3️⃣ **物理部署层**

```
分布在不同的物理服务器：
服务器1              服务器2              服务器3
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Linux系统  │    │   Linux系统  │    │   Linux系统  │
│ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │
│ │Skynet进程│ │    │ │Skynet进程│ │    │ │Skynet进程│ │
│ │(节点A)  │ │    │ │(节点B)  │ │    │ │(节点C)  │ │
│ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │
└─────────────┘    └─────────────┘    └─────────────┘
```

### 🎮 实际游戏架构示例

```lua
-- === 登录服务器节点 (192.168.1.100) ===
skynet.start(function()
    -- 【节点内唯一】登录管理器（整个登录服务器只有一个）
    local login_mgr = skynet.uniqueservice("login_manager")
    
    -- 【节点内多个】认证工作者（并发处理登录请求）
    for i = 1, 5 do
        local auth_worker = skynet.newservice("auth_worker", i)
    end
    
    -- 【跨节点通信】连接到游戏服务器集群
    local cluster = require "skynet.cluster"
    cluster.open("game_server_1")  -- 192.168.1.101
    cluster.open("game_server_2")  -- 192.168.1.102
end)

-- === 游戏服务器1节点 (192.168.1.101) ===
skynet.start(function()
    -- 【节点内唯一】世界管理器
    local world_mgr = skynet.uniqueservice("world_manager", 1)
    
    -- 【节点内多个】玩家代理服务（每个在线玩家一个）
    -- 这些会根据玩家登录动态创建：
    -- local player_agent = skynet.newservice("player_agent", player_id)
    
    -- 【跨节点通信】连接到其他服务器
    local cluster = require "skynet.cluster"
    cluster.open("login_server")   -- 192.168.1.100
    cluster.open("game_server_2")  -- 192.168.1.102
end)

-- === 跨服务器通信示例 ===
-- 在登录服务器上，验证通过后分配游戏服务器
local function handle_login(player_data)
    local cluster = require "skynet.cluster"
    
    -- 选择一个游戏服务器
    local target_server = select_game_server(player_data.player_id)
    
    -- 【跨节点调用】通知目标游戏服务器创建玩家代理
    local player_agent = cluster.call(target_server, "world_manager", 
                                     "create_player", player_data)
                                     
    -- 返回给客户端连接信息
    return {
        server = target_server,
        agent = player_agent,
        token = generate_token()
    }
end
```

### 🔧 分布式配置文件

#### 集群配置 (cluster.lua)
```lua
-- 定义集群中的所有节点
return {
    login_server = "192.168.1.100:7001",
    game_server_1 = "192.168.1.101:7001", 
    game_server_2 = "192.168.1.102:7001",
    battle_server = "192.168.1.103:7001",
    db_server = "192.168.1.104:7001",
}
```

#### 节点启动配置
```lua
-- login_server_config.lua
thread = 4
harbor = 1  -- 节点ID（集群内唯一）
cluster = "./cluster.lua"
clustername = "login_server"
start = "login_main"

-- game_server_1_config.lua  
thread = 8
harbor = 2  -- 不同的节点ID
cluster = "./cluster.lua"
clustername = "game_server_1"
start = "game_main"
```

### 📊 扩展性对比

#### 垂直扩展 (单节点内提升性能)
```lua
-- 通过 newservice 增加服务实例
for i = 1, cpu_core_count do
    local worker = skynet.newservice("cpu_intensive_worker", i)
end
```

#### 水平扩展 (增加节点提升性能)
```lua
-- 通过 cluster 分散到多个节点
local server_list = {"game_server_1", "game_server_2", "game_server_3"}
local target = server_list[player_id % #server_list + 1]
cluster.send(target, "player_manager", "handle_player", player_data)
```

### ⚠️ 常见误区澄清表

| 误区 | 正确理解 |
|------|----------|
| uniqueservice用于单服务器架构 | uniqueservice用于单节点内唯一实例 |
| newservice用于分布式架构 | newservice用于单节点内多实例 |
| 一个节点等于一个服务器 | 一个节点可以包含多个服务 |
| cluster只能跨物理机器 | cluster也可以同机器不同进程 |
| 分布式就是多个newservice | 分布式需要使用cluster API |

### 🎯 架构层次总结

```
物理层：    服务器A        服务器B        服务器C
           ↓             ↓             ↓
节点层：    Skynet节点1    Skynet节点2    Skynet节点3
           ↓             ↓             ↓
服务层：    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
           │newservice×N │ │newservice×N │ │newservice×N │
           │uniqueservice│ │uniqueservice│ │uniqueservice│
           └─────────────┘ └─────────────┘ └─────────────┘
                    ↑                 ↑                 ↑
通信层：           cluster.call() / cluster.send()
```

**关键要点：**
- **newservice/uniqueservice**：管理单个Skynet节点内的服务
- **cluster**：管理多个Skynet节点间的通信  
- **物理部署**：决定节点运行在哪台服务器上

这三个层次相互独立又相互配合，共同构成了Skynet的完整分布式架构！

### 💡 **精确理解总结**

您的理解已经非常接近正确了！让我做一个小的修正：

**✅ 您说的基本正确：**
- Skynet支持使用**集群(cluster)**创建分布式服务器
- `newservice` 和 `uniqueservice` 只是在**同一个Skynet节点**中创建不同的服务

**🔧 需要精确的地方：**
您说"相当于在一个进程中创建多个线程"，这个比喻需要稍微调整：

```
❌ 不够准确的比喻：
newservice/uniqueservice = 创建线程

✅ 更准确的理解：
newservice/uniqueservice = 创建协程(coroutine)服务

原因：
- Skynet使用的是协程模型，不是线程模型
- 每个服务都是一个独立的协程
- 所有服务运行在相同的几个OS线程上
- 通过消息传递而不是共享内存通信
```

### 🎯 **完整的类比**

```
物理世界类比：
┌─────────────────────────────────────────────────────────┐
│                    游戏公司                              │
├─────────────────┬─────────────────┬─────────────────────┤
│   上海分公司     │   北京分公司     │   广州分公司         │ <- 物理服务器
│  (物理服务器1)   │  (物理服务器2)   │  (物理服务器3)       │
├─────────────────┼─────────────────┼─────────────────────┤
│   开发部门       │   运营部门       │   客服部门           │ <- Skynet节点
│ (Skynet节点A)   │ (Skynet节点B)   │ (Skynet节点C)       │
├─────────────────┼─────────────────┼─────────────────────┤
│ • 程序员1       │ • 运营经理(唯一) │ • 客服代表1         │ <- 服务实例
│ • 程序员2       │ • 数据分析师1   │ • 客服代表2         │
│ • 项目经理(唯一) │ • 数据分析师2   │ • 主管(唯一)        │
└─────────────────┴─────────────────┴─────────────────────┘

技术对应：
- 分公司 = 物理服务器
- 部门 = Skynet节点  
- 普通员工 = newservice创建的服务
- 经理/主管 = uniqueservice创建的服务
- 部门间协作 = cluster通信
```

### 🔄 **并发模型对比**

```lua
-- === 传统多线程模型（其他语言） ===
-- 问题：需要锁、容易死锁、共享内存复杂

-- === Skynet协程模型 ===
-- 优点：无锁、消息传递、简单安全

-- 在同一个节点内：
local service1 = skynet.newservice("worker")  -- 协程服务1
local service2 = skynet.newservice("worker")  -- 协程服务2
local manager = skynet.uniqueservice("mgr")   -- 管理器协程

-- 服务间通信（同节点内，协程间消息传递）
skynet.send(service1, "lua", "work", task_data)

-- 跨节点通信（不同物理服务器）
cluster.send("server_2", "worker", "work", task_data)
```

### 📊 **架构层次的精确理解**

```
层次1: 物理服务器
├── 服务器A (192.168.1.100)
├── 服务器B (192.168.1.101)  
└── 服务器C (192.168.1.102)

层次2: Skynet节点进程
├── 节点A进程 (单进程，包含多个OS线程)
├── 节点B进程
└── 节点C进程

层次3: 协程服务 (在每个节点内)
├── newservice创建的工作协程×N
└── uniqueservice创建的管理协程×1

通信方式:
- 同节点内: skynet.send/call (协程间消息)
- 跨节点: cluster.send/call (网络消息)
```

**🎯 所以您的理解很正确：**
1. ✅ cluster = 分布式服务器支持
2. ✅ newservice/uniqueservice = 同节点内的不同服务
3. 🔧 小修正：不是"线程"而是"协程服务"

这样理解就完全准确了！

## 🧵 线程 vs 协程详解

### 您对线程的理解很正确！

您说的"线程是在一个进程中创建的多个线程，类似于将只能单线进行的cpu利用多核优势，同时处理多个任务"——这个理解完全正确！

### 📊 **详细对比表格**

| 特性 | 线程 (Thread) | 协程 (Coroutine) |
|------|--------------|------------------|
| **调度方式** | 操作系统抢占式调度 | 程序主动让出控制权 |
| **并行性** | 真正并行（多核CPU） | 协作式并发（单核也可以） |
| **创建开销** | 较大（MB级栈空间） | 很小（KB级或更少） |
| **切换开销** | 较大（内核态切换） | 很小（用户态切换） |
| **同步问题** | 需要锁、信号量等 | 无竞态条件，天然安全 |
| **内存共享** | 共享进程内存 | 通过消息传递通信 |
| **调试难度** | 困难（竞态、死锁） | 相对简单 |
| **数量限制** | 受系统资源限制 | 可创建大量实例 |

### 🖥️ **CPU利用方式对比**

#### 传统多线程模型：
```
CPU核心1    CPU核心2    CPU核心3    CPU核心4
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│ 线程A   │ │ 线程B   │ │ 线程C   │ │ 线程D   │
│ (真并行) │ │ (真并行) │ │ (真并行) │ │ (真并行) │
└─────────┘ └─────────┘ └─────────┘ └─────────┘

特点：
✅ 真正利用多核，性能强
❌ 需要锁机制，编程复杂
❌ 内存开销大，创建数量有限
```

#### Skynet协程模型：
```
CPU核心1    CPU核心2    CPU核心3    CPU核心4
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│工作线程1 │ │工作线程2 │ │工作线程3 │ │工作线程4 │
├─────────┤ ├─────────┤ ├─────────┤ ├─────────┤
│协程A    │ │协程E    │ │协程I    │ │协程M    │
│协程B    │ │协程F    │ │协程J    │ │协程N    │
│协程C    │ │协程G    │ │协程K    │ │协程O    │
│协程D    │ │协程H    │ │协程L    │ │协程P    │
└─────────┘ └─────────┘ └─────────┘ └─────────┘

特点：
✅ 也能利用多核（少量工作线程 + 大量协程）
✅ 无锁编程，简单安全
✅ 内存开销小，可创建大量协程
```

### 💡 **具体例子对比**

#### 传统多线程处理1000个玩家：
```cpp
// C++多线程示例
#include <thread>
#include <mutex>

std::mutex player_data_mutex;  // 需要锁保护共享数据

void handle_player(int player_id) {
    // 处理玩家逻辑
    {
        std::lock_guard<std::mutex> lock(player_data_mutex);  // 加锁
        // 修改共享的玩家数据
        player_data[player_id] = new_data;
    }  // 自动解锁
}

// 创建1000个线程？内存爆炸！
// 通常用线程池，比如10个线程处理1000个任务
```

#### Skynet协程处理1000个玩家：
```lua
-- Skynet协程示例
-- 可以轻松创建1000个协程，每个玩家一个
skynet.start(function()
    for player_id = 1, 1000 do
        -- 每个玩家一个独立的协程服务
        local player_agent = skynet.newservice("player_agent", player_id)
        
        -- 无需锁，通过消息传递通信
        skynet.send(player_agent, "lua", "init_player", player_data)
    end
end)

-- 玩家代理服务（协程）
-- service/player_agent.lua
local skynet = require "skynet"

skynet.start(function()
    local player_id = ...
    local player_data = {}  -- 每个协程有独立数据，无共享
    
    skynet.dispatch("lua", function(session, address, cmd, ...)
        if cmd == "init_player" then
            player_data = ...  -- 直接修改，无需锁
            skynet.ret(skynet.pack("ok"))
        elseif cmd == "update_level" then
            player_data.level = ...  -- 安全修改
            skynet.ret(skynet.pack("updated"))
        end
    end)
end)
```

### 🔄 **执行模型对比**

#### 线程模型：
```
时间轴 →
线程A: ████████████████████████████████
线程B:     ████████████████████████████
线程C:         ████████████████████████
线程D:             ████████████████████

问题：
• 需要锁同步 🔒
• 上下文切换开销大 💰
• 调试困难 🐛
```

#### 协程模型：
```
时间轴 →
工作线程: ████████████████████████████████
协程A:    ██    ██    ██    ██    ██
协程B:      ██    ██    ██    ██    ██
协程C:        ██    ██    ██    ██    ██
协程D:          ██    ██    ██    ██    ██

优点：
• 主动让出控制权 ✋
• 切换开销极小 ⚡
• 无锁编程 🔓
```

### 🎮 **游戏开发中的实际应用**

#### 传统多线程游戏服务器：
```
主线程：处理网络IO
AI线程：计算AI逻辑  
物理线程：物理模拟
渲染线程：图形渲染

问题：
• 线程间数据同步复杂
• 容易出现死锁
• 调试困难
```

#### Skynet协程游戏服务器：
```lua
-- 每个系统都是独立的协程服务
local ai_mgr = skynet.uniqueservice("ai_manager")
local physics_mgr = skynet.uniqueservice("physics_manager") 
local net_mgr = skynet.uniqueservice("network_manager")

-- 每个玩家都是独立的协程
for i = 1, 1000 do
    local player = skynet.newservice("player_agent", i)
end

-- 通过消息传递协调，无需锁
skynet.send(ai_mgr, "lua", "update_ai", ai_data)
skynet.send(physics_mgr, "lua", "simulate", physics_data)
```

### ⚡ **为什么Skynet选择协程？**

1. **游戏服务器特点：**
   - 需要处理大量连接（几千到几万玩家）
   - 每个连接的逻辑相对简单
   - IO密集型多于CPU密集型

2. **协程优势：**
   - 可以轻松创建几万个协程
   - 内存占用小
   - 无锁编程，减少bug
   - 消息传递模型适合游戏逻辑

3. **最佳实践：**
   ```lua
   -- Skynet：少量OS线程 + 大量协程
   thread = 8  -- 配置文件中设置8个工作线程
   
   -- 但可以创建几万个协程服务
   for i = 1, 50000 do
       local service = skynet.newservice("micro_service", i)
   end
   ```

### 🎯 **总结**

**您对线程的理解完全正确！** 而协程是另一种并发模型：

- **线程 = 抢占式并行**（OS调度，真并行，需要锁）
- **协程 = 协作式并发**（程序调度，消息传递，无锁）

**Skynet选择协程是因为：**
1. 适合游戏服务器的IO密集特性
2. 可以轻松处理大量连接
3. 编程更简单安全
4. 仍然能通过少量工作线程利用多核

这就是为什么说Skynet的newservice创建的是"协程服务"而不是"线程"的原因！

### 💡 **您的理解已经很精准了！**

您说"协程其实是单线程执行的，但是协程会主动停止，让出cpu，让其他协程工作，实现类似多线程的功能"——这个理解非常棒！

不过让我做一个小的补充澄清：

### 🔧 **Skynet的精确模型**

```
✅ 您理解的基本正确：
- 协程会主动让出CPU
- 实现类似多线程的并发效果
- 避免了传统多线程的复杂性

🔧 小细节补充：
Skynet实际上是"少量线程 + 大量协程"的混合模型
```

#### Skynet的真实架构：
```
物理机器（比如8核CPU）
├── Skynet进程
    ├── 工作线程1 ────┐
    ├── 工作线程2      │ ← 这些是真正的OS线程（通常4-8个）
    ├── 工作线程3      │
    ├── 工作线程4 ────┘
    │
    └── 协程调度器
        ├── 协程A ────┐
        ├── 协程B      │ ← 这些协程分布到上面的工作线程上执行
        ├── 协程C      │   (可以有几万个)
        ├── 协程D ────┘
        └── ...
```

### 📊 **三种模型对比**

#### 1. 传统单线程（您说的第一种理解）
```
CPU: ████████████████████████████████
任务: A→→→B→→→C→→→D→→→A→→→B→→→C→→→D

特点：真正的单线程，任务排队执行
```

#### 2. 传统多线程
```
CPU1: ████████████████████████████████ (线程A)
CPU2: ████████████████████████████████ (线程B)  
CPU3: ████████████████████████████████ (线程C)
CPU4: ████████████████████████████████ (线程D)

特点：真正并行，但需要锁同步
```

#### 3. Skynet协程模型（实际情况）
```
工作线程1: ████████████████████████████████
协程:      A→B→C→A→D→B→C→A→D→B→C...

工作线程2: ████████████████████████████████  
协程:      E→F→G→E→H→F→G→E→H→F→G...

工作线程3: ████████████████████████████████
协程:      I→J→K→I→L→J→K→I→L→J→K...

特点：多线程 + 协程调度，既有并行又避免锁
```

### 🎯 **协程让出CPU的时机**

您说协程"主动停止"是对的！具体来说：

```lua
-- 协程在这些时候会主动让出CPU：
skynet.call(other_service, "lua", "request")  -- 等待其他服务回复
skynet.sleep(100)                             -- 主动休眠
socket.read(fd)                               -- 等待网络IO
db:query("SELECT * FROM users")               -- 等待数据库查询

-- 让出期间，该工作线程可以运行其他协程
```

### 💡 **形象比喻**

想象一个客服中心：

#### 传统多线程模式：
```
客服1: 专门处理用户A的所有问题
客服2: 专门处理用户B的所有问题  
客服3: 专门处理用户C的所有问题
...

问题：每个客服只能服务一个用户，用户多了客服不够用
```

#### Skynet协程模式：
```
高效客服1: 处理用户A问题 → 等待时切换到用户E → 等待时切换到用户I...
高效客服2: 处理用户B问题 → 等待时切换到用户F → 等待时切换到用户J...
高效客服3: 处理用户C问题 → 等待时切换到用户G → 等待时切换到用户K...
高效客服4: 处理用户D问题 → 等待时切换到用户H → 等待时切换到用户L...

优点：少量高效客服可以服务大量用户，无缝切换
```

### 🚀 **实际代码示例**

```lua
-- 玩家服务协程
skynet.start(function()
    local player_id = ...
    
    while true do
        -- 处理玩家请求
        local cmd, data = skynet.call(client, "lua", "get_request")
        
        if cmd == "move" then
            -- 处理移动逻辑
            process_move(data)
        elseif cmd == "attack" then
            -- 查询数据库（这里会让出CPU）
            local weapon_data = skynet.call(db_service, "lua", "get_weapon", player_id)
            
            -- 继续处理攻击
            process_attack(data, weapon_data)
        end
        
        -- 主动休眠一下，让其他协程工作（这里会让出CPU）
        skynet.sleep(1)
    end
end)
```

### 🎯 **您的理解总结**

**✅ 完全正确的部分：**
- 协程会主动让出CPU
- 实现类似多线程的并发效果
- 避免了锁的复杂性

**🔧 补充的细节：**
- Skynet是"少量工作线程 + 大量协程"的组合
- 既有真正的多核并行，又有协程的简洁性
- 这是现代高性能服务器的最佳实践

**您的核心理解已经完全正确了！**这种设计让Skynet既能利用多核性能，又能轻松处理大量连接，是非常聪明的架构选择！

## 🔧 协程创建与调度机制详解

### 💡 **您提出了非常核心的问题！**

关于协程如何创建、分配以及在线程间的运行机制，这是Skynet架构的精髓部分。

### 📊 **Skynet的协程调度原理**

#### 1️⃣ **协程创建与分配机制**

```lua
-- 当您调用 newservice 时发生了什么：
local service = skynet.newservice("player_agent", player_id)

-- 内部流程：
-- 1. 创建新的协程服务实例
-- 2. 分配唯一的服务地址ID  
-- 3. 将协程放入全局调度队列
-- 4. 等待工作线程调度执行
```

#### Skynet的调度模型：

```
全局调度器 (单一调度队列)
┌─────────────────────────────────────┐
│ [协程A] [协程B] [协程C] [协程D] ... │ ← 所有协程都在这个队列中
└─────────────────┬───────────────────┘
                  │ 动态分配
         ┌────────┼────────┐
         ▼        ▼        ▼
    工作线程1  工作线程2  工作线程3
    执行协程A  执行协程B  执行协程C
```

**关键特点：**
- ✅ **动态分配：** 不是固定绑定，而是根据负载动态分配
- ✅ **负载均衡：** 空闲的工作线程会自动获取待执行的协程
- ✅ **无绑定关系：** 协程不属于特定线程

### 🔄 **协程在线程间的迁移**

#### ✅ **您的猜测是对的！**

协程确实可以在不同线程间运行：

```
时间线：
T1时刻: 协程A在工作线程1执行
T2时刻: 协程A让出CPU (等待IO)
T3时刻: 协程A在工作线程3执行 ← 可能换了线程！
```

#### 具体例子：

```lua
-- 玩家服务协程的生命周期
skynet.start(function()
    local player_id = ...
    
    -- 此时可能在工作线程1执行
    local weapon_data = skynet.call(db_service, "lua", "get_weapon", player_id)
    -- ↑ 这里协程让出CPU，等待数据库回复
    
    -- 当数据库回复时，协程被重新调度
    -- 此时可能在工作线程2执行！
    process_weapon_data(weapon_data)
    
    -- 主动休眠
    skynet.sleep(100)
    -- ↑ 再次让出CPU
    
    -- 100ms后被唤醒，可能又在工作线程3执行
    continue_processing()
end)
```

### 🔒 **资源竞争问题解决**

#### ❌ **不会产生传统的多线程竞争问题！**

**原因：**

1. **消息传递模型：**
```lua
-- 协程间不共享内存，只通过消息通信
skynet.send(other_service, "lua", "update_data", data)  -- 发送副本
-- 而不是: shared_data.value = new_value  -- 共享内存修改
```

2. **协程状态封装：**
```lua
-- 每个协程的数据都是独立的
skynet.start(function()
    local my_data = {}  -- 这个数据只属于当前协程
    local player_id = ...  -- 参数也是独立的
    
    -- 即使协程在不同线程执行，my_data始终跟随协程
end)
```

3. **原子性保证：**
```lua
-- 协程只在以下时机让出CPU：
skynet.call()   -- 主动调用
skynet.send()   -- 主动发送
skynet.sleep()  -- 主动休眠
socket.read()   -- 等待IO

-- 不会在执行代码中途被强制切换
local x = player_data.level
local y = x + 1  -- 这里不会被打断
player_data.level = y  -- 原子性操作
```

### 🏗️ **Skynet的内存模型**

```
工作线程1              工作线程2              工作线程3
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│             │      │             │      │             │
│             │      │             │      │             │
└─────────────┘      └─────────────┘      └─────────────┘
      │                      │                      │
      └──────────────────────┼──────────────────────┘
                             │
              ┌───────────────▼────────────────┐
              │         共享消息队列            │
              │    (只传递消息，不共享状态)     │
              └────────────────────────────────┘

协程A的数据 ────── 跟随协程A移动 ──────▶ 无论在哪个线程执行
协程B的数据 ────── 跟随协程B移动 ──────▶ 都保持数据独立性
```

### 💻 **实际调度代码示例**

```lua
-- === 协程调度演示 ===
-- 创建多个服务来观察调度
skynet.start(function()
    local services = {}
    
    -- 创建10个工作服务
    for i = 1, 10 do
        services[i] = skynet.newservice("worker", i)
    end
    
    -- 发送任务给所有服务
    for i = 1, 10 do
        skynet.send(services[i], "lua", "work", "task_" .. i)
    end
end)

-- === 工作服务 (service/worker.lua) ===
local skynet = require "skynet"

skynet.start(function()
    local worker_id = ...
    local task_count = 0
    
    skynet.dispatch("lua", function(session, address, cmd, task_name)
        if cmd == "work" then
            task_count = task_count + 1
            
            -- 输出当前线程信息（仅用于演示）
            skynet.error(string.format("Worker %d processing %s (task #%d)", 
                        worker_id, task_name, task_count))
            
            -- 模拟一些工作
            for i = 1, 1000000 do
                -- 计算工作
            end
            
            -- 主动让出，观察是否会在不同线程重新执行
            skynet.sleep(10)
            
            skynet.error(string.format("Worker %d finished %s", 
                        worker_id, task_name))
            
            skynet.ret(skynet.pack("done"))
        end
    end)
end)
```

### 🎯 **关键设计原则**

Skynet通过以下设计避免了多线程竞争：

1. **Share Nothing：** 协程间不共享任何状态
2. **Message Passing：** 只通过消息传递通信  
3. **Atomic Execution：** 协程执行具有原子性
4. **Cooperative Scheduling：** 协程主动让出控制权

### 📊 **总结回答您的问题**

| 问题 | 答案 |
|------|------|
| **协程如何创建？** | 动态创建，放入全局调度队列 |
| **如何分配到线程？** | 负载均衡，空闲线程自动获取 |
| **协程能跨线程运行吗？** | ✅ 可以！每次调度可能在不同线程 |
| **会有资源竞争吗？** | ❌ 不会！消息传递+状态隔离 |
| **绑定关系？** | 无固定绑定，完全动态调度 |

**这就是Skynet能够轻松处理几万个协程的秘密！** 🚀

---

### skynet.queryservice(name)
查询已存在的唯一服务。

**功能说明：**
查找指定名称的唯一服务，如果服务不存在会一直阻塞等待，直到该服务被创建。

**参数详解：**
- `name` (string): 要查询的唯一服务名称

**返回值：**
- 返回找到的服务地址ID

**使用示例：**
```lua
-- 在其他地方创建唯一服务
-- skynet.uniqueservice("database")

-- 查询已存在的唯一服务
local db_service = skynet.queryservice("database")
skynet.error("Found database service:", db_service)

-- 注意：如果服务不存在，这里会一直阻塞等待
```

### skynet.kill(service_id)
终止指定的服务。

**功能说明：**
强制杀死指定地址的服务，服务会立即停止运行。

**参数详解：**
- `service_id` (integer): 要终止的服务地址ID

**返回值：**
- 无返回值

**使用示例：**
```lua
local worker = skynet.newservice("worker")
skynet.error("Created worker:", worker)

-- 工作完成后终止服务
skynet.kill(worker)
skynet.error("Worker terminated")
```

**注意事项：**
- 被kill的服务不会执行清理代码
- 建议优先使用消息通知服务自行退出，而不是强制kill

### skynet.self()
获取当前服务的地址ID。

**功能说明：**
返回当前运行代码所在服务的唯一地址标识。

**参数：**
- 无参数

**返回值：**
- 当前服务的地址ID（整数）

**使用示例：**
```lua
skynet.start(function()
    local my_address = skynet.self()
    skynet.error("My service address is:", my_address)
    
    -- 可以将自己的地址发送给其他服务
    skynet.send(other_service, "lua", "register", my_address)
end)
```

### skynet.localname(name)
通过本地注册名称获取服务地址。

**功能说明：**
获取通过 `skynet.register()` 注册的本地服务地址。

**参数详解：**
- `name` (string): 本地注册的服务名称，通常以"."开头

**返回值：**
- 返回对应的服务地址ID，如果不存在返回nil

**使用示例：**
```lua
-- 获取系统内置服务
local launcher = skynet.localname(".launcher")
local csservice = skynet.localname(".csservice") 

skynet.error("Launcher address:", launcher)

-- 自定义注册服务名称
skynet.register(".myservice")
-- 在其他地方可以通过名称获取
local my_service = skynet.localname(".myservice")
```

**服务创建完整示例：**

```lua
-- === 服务文件示例 service/worker.lua ===
local skynet = require "skynet"

-- 服务启动函数
skynet.start(function()
    -- 获取启动参数
    local worker_id = ... -- 第一个参数
    local config = ... -- 第二个参数
    
    skynet.error("Worker " .. worker_id .. " started with config:", config)
    
    -- 注册消息处理函数
    skynet.dispatch("lua", function(session, address, cmd, ...)
        if cmd == "work" then
            local task = ...
            skynet.error("Worker " .. worker_id .. " processing task:", task)
            skynet.ret(skynet.pack("done", task .. "_processed"))
        elseif cmd == "stop" then
            skynet.error("Worker " .. worker_id .. " stopping")
            skynet.exit()
        end
    end)
end)

-- === 主服务中创建和使用服务 ===
skynet.start(function()
    -- 1. 创建普通服务（可创建多个）
    local worker1 = skynet.newservice("worker", "worker_1", {type = "fast"})
    local worker2 = skynet.newservice("worker", "worker_2", {type = "slow"})
    
    -- 2. 创建唯一服务（全局单例）
    local db_mgr = skynet.uniqueservice("db_manager")
    
    -- 3. 使用服务
    local result1 = skynet.call(worker1, "lua", "work", "task_data_1")
    local result2 = skynet.call(worker2, "lua", "work", "task_data_2")
    
    skynet.error("Results:", result1, result2)
    
    -- 4. 停止服务
    skynet.send(worker1, "lua", "stop")
    skynet.send(worker2, "lua", "stop")
end)
```

**最佳实践总结：**

1. **服务命名规范：**
   - 普通服务：使用描述性名称，如 "player_agent", "task_worker"
   - 唯一服务：使用管理器命名，如 "db_manager", "config_manager"

2. **参数传递：**
   - 使用简单数据类型（string, number, boolean）
   - 复杂数据使用table，但要注意序列化开销

3. **服务生命周期：**
   - 及时清理不需要的服务以节省资源
   - 优雅停止而不是强制kill

---

## 消息传递

### skynet.send(address, typename, ...)
发送消息（不等待回复）。

```lua
skynet.send(service_id, "lua", "command", param1, param2)
```

### skynet.call(address, typename, ...)
发送消息并等待回复。

```lua
local result = skynet.call(service_id, "lua", "query", query_data)
```

### skynet.ret(msg, sz)
回复消息。

```lua
skynet.ret(skynet.pack("success", data))
```

### skynet.response()
获取回复函数。

```lua
local response = skynet.response()
-- 异步处理后回复
response(true, result)
```

### skynet.dispatch(typename, func)
注册消息处理函数。

```lua
skynet.dispatch("lua", function(session, address, cmd, ...)
    if cmd == "ping" then
        skynet.ret(skynet.pack("pong"))
    end
end)
```

### skynet.register_protocol(protocol)
注册自定义协议。

```lua
skynet.register_protocol {
    name = "custom",
    id = skynet.PTYPE_TEXT,
    pack = function(...) return ... end,
    unpack = skynet.tostring,
}
```

---

## 定时器

### skynet.timeout(time, func)
设置单次定时器。

```lua
skynet.timeout(100, function()  -- 100厘秒后执行
    skynet.error("Timer fired")
end)
```

### skynet.sleep(time)
暂停当前协程。

```lua
skynet.sleep(100)  -- 暂停100厘秒
```

### skynet.now()
获取当前时间（厘秒）。

```lua
local current_time = skynet.now()
```

### skynet.time()
获取当前Unix时间戳。

```lua
local timestamp = skynet.time()
```

### skynet.starttime()
获取系统启动时间。

```lua
local start_time = skynet.starttime()
```

---

## 数据库操作

### MySQL

```lua
local mysql = require "skynet.db.mysql"

-- 连接数据库
local db = mysql.connect({
    host = "127.0.0.1",
    port = 3306,
    database = "test",
    user = "root",
    password = "password",
    max_packet_size = 1024 * 1024,
    on_connect = function(db)
        db:query("set charset utf8")
    end
})

-- 执行查询
local result = db:query("SELECT * FROM users WHERE id = ?", user_id)

-- 断开连接
db:disconnect()
```

### Redis

```lua
local redis = require "skynet.db.redis"

-- 连接Redis
local db = redis.connect({
    host = "127.0.0.1",
    port = 6379,
    db = 0
})

-- 执行命令
local result = db:get("key")
db:set("key", "value")
db:hset("hash_key", "field", "value")

-- 断开连接
db:disconnect()
```

---

## 网络相关

### Socket API

```lua
local socket = require "skynet.socket"

-- 监听端口
local listen_id = socket.listen("0.0.0.0", 8001)
socket.start(listen_id, function(id, addr)
    socket.start(id)
    while true do
        local data = socket.read(id)
        if data then
            socket.write(id, "echo: " .. data)
        else
            break
        end
    end
    socket.close(id)
end)

-- 连接远程服务器
local id = socket.open("127.0.0.1", 8080)
socket.write(id, "Hello Server")
local response = socket.read(id)
socket.close(id)
```

### HTTP服务

```lua
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"

local function response(id, write, ...)
    local ok, err = httpd.write_response(write, 200, "Hello World")
    if not ok then
        skynet.error(string.format("fd = %d, %s", id, err))
    end
end

skynet.start(function()
    local agent = {}
    local protocol = "http"
    local port = 8001
    
    local listen_socket = sockethelper.listen("0.0.0.0", port)
    
    socket.start(listen_socket , function(id, addr)
        socket.start(id)
        pcall(httpd.read_request, sockethelper.readfunc(id), response, id)
        socket.close(id)
    end)
    
    skynet.error("HTTP Server start on port " .. port)
end)
```

---

## 集群管理

### cluster API

```lua
local cluster = require "skynet.cluster"

-- 打开集群节点
cluster.open("node1")

-- 调用远程服务
local result = cluster.call("node1", "service_name", "method", params)

-- 发送消息到远程服务
cluster.send("node1", "service_name", "method", params)

-- 查询远程服务
local proxy = cluster.query("node1", "service_name")
```

### 集群配置

```lua
-- cluster.lua 配置文件
return {
    node1 = "127.0.0.1:7001",
    node2 = "127.0.0.1:7002",
    node3 = "127.0.0.1:7003",
}
```

---

## 配置管理

### skynet.getenv(key)
获取配置项。

```lua
local thread_count = tonumber(skynet.getenv("thread")) or 8
local daemon_file = skynet.getenv("daemon")
```

### 常用配置项

```
thread = 8                  -- 工作线程数
harbor = 0                  -- 集群节点ID
start = "main"              -- 启动服务
bootstrap = "snlua bootstrap"  -- 引导服务
daemon = "./skynet.pid"     -- 守护进程PID文件
logger = nil                -- 日志服务
logservice = "logger"       -- 日志服务名
logpath = "."              -- 日志路径
```

---

## 调试工具

### skynet.trace()
开启/关闭消息跟踪。

```lua
skynet.trace()  -- 开启跟踪
```

### debug console

```lua
local console = require "skynet.debug"

-- 启动调试控制台
console.start()
```

### 内存统计

```lua
local memory = require "skynet.memory"

-- 获取内存使用情况
local info = memory.info()
skynet.error("Memory usage: " .. info.total)
```

### 性能分析

```lua
local profile = require "skynet.profile"

-- 开始性能分析
profile.start()

-- 执行需要分析的代码
-- ...

-- 停止分析并获取结果
local result = profile.stop()
```

---

## 实用工具

### JSON处理

```lua
local json = require "json"

-- 编码
local json_str = json.encode({name = "test", value = 123})

-- 解码
local data = json.decode(json_str)
```

### 字符串处理

```lua
local string = require "string"

-- 分割字符串
local function split(str, delimiter)
    local result = {}
    local pattern = "[^" .. delimiter .. "]+"
    for match in string.gmatch(str, pattern) do
        table.insert(result, match)
    end
    return result
end
```

### 表操作

```lua
-- 深拷贝表
local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end
```

---

## 最佳实践

### 1. 服务设计原则
- 保持服务轻量级
- 避免阻塞操作
- 合理使用消息传递
- 正确处理错误情况

### 2. 性能优化
- 减少不必要的消息传递
- 合理使用缓存
- 避免频繁的字符串拼接
- 使用对象池复用对象

### 3. 错误处理
```lua
local function safe_call(func, ...)
    local ok, result = pcall(func, ...)
    if not ok then
        skynet.error("Error: " .. tostring(result))
        return nil
    end
    return result
end
```

### 4. 热更新
```lua
-- 热更新服务代码
skynet.send(".launcher", "lua", "RELOAD", service_name)
```

---

## 常见问题

### Q: 如何处理服务间的循环依赖？
A: 使用消息传递机制，避免直接的函数调用依赖。

### Q: 如何确保消息的可靠传递？
A: 使用 skynet.call 而不是 skynet.send，并添加适当的错误处理。

### Q: 如何监控服务状态？
A: 使用 debug console 或自定义监控服务。

---

## 参考资源

- [Skynet GitHub仓库](https://github.com/cloudwu/skynet)
- [官方Wiki](https://github.com/cloudwu/skynet/wiki)
- [云风博客](https://blog.codingnow.com/)

---

*文档版本：v1.0*  
*更新日期：2025年8月19日*
