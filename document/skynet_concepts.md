# Skynet 框架核心概念

## 目录
1. [框架简介](#框架简介)
2. [架构设计](#架构设计)
3. [服务模型](#服务模型)
4. [线程与协程](#线程与协程)
5. [消息传递机制](#消息传递机制)
6. [分布式架构](#分布式架构)
7. [协程调度机制](#协程调度机制)
8. [最佳实践](#最佳实践)

---

## 框架简介

Skynet 是一个轻量级的分布式游戏服务器框架，使用 C + Lua 开发。它采用 Actor 模型，每个服务都是独立的 Actor，通过消息传递进行通信。

### 核心特点
- 轻量级，高性能
- 基于消息传递的并发模型
- 支持热更新
- 内置集群支持
- 简单易用的API

---

## 架构设计

### 整体架构
```
┌─────────────────────────────────────────────────────────┐
│                    Skynet 框架                          │
├─────────────────┬─────────────────┬─────────────────────┤
│   物理服务器1    │   物理服务器2    │   物理服务器3        │
├─────────────────┼─────────────────┼─────────────────────┤
│   Skynet节点A   │   Skynet节点B   │   Skynet节点C       │
├─────────────────┼─────────────────┼─────────────────────┤
│ • 工作线程1-4   │ • 工作线程1-4   │ • 工作线程1-4       │
│ • 协程服务×N    │ • 协程服务×N    │ • 协程服务×N        │
└─────────────────┴─────────────────┴─────────────────────┘
```

### 三层架构模型

#### 1. 物理部署层
不同的Skynet节点可以部署在不同的物理服务器上，实现真正的分布式部署。

#### 2. 节点进程层
每个Skynet节点是一个独立的进程，包含少量工作线程（通常4-8个）。

#### 3. 协程服务层
在每个节点内，可以创建大量的协程服务（几千到几万个）。

---

## 服务模型

### 服务类型对比

| 特性 | newservice | uniqueservice |
|------|------------|---------------|
| **实例数量** | 可创建多个实例 | 全节点唯一实例 |
| **使用场景** | 工作进程、玩家代理 | 管理器、配置服务 |
| **并发处理** | 多实例并行处理 | 单实例串行处理 |
| **资源消耗** | 多实例消耗更多 | 单实例节省资源 |

### 应用场景

#### newservice 适用场景
- 玩家代理服务（每个玩家一个）
- 任务处理器（并行处理）
- 工作线程池

#### uniqueservice 适用场景
- 数据库连接管理器
- 配置管理服务
- 全局统计服务
- 日志处理服务

---

## 线程与协程

### 概念对比

| 特性 | 线程 (Thread) | 协程 (Coroutine) |
|------|--------------|------------------|
| **调度方式** | 操作系统抢占式调度 | 程序主动让出控制权 |
| **并行性** | 真正并行（多核CPU） | 协作式并发 |
| **创建开销** | 大（MB级栈空间） | 小（KB级或更少） |
| **切换开销** | 大（内核态切换） | 小（用户态切换） |
| **同步问题** | 需要锁、信号量等 | 无竞态条件 |
| **数量限制** | 受系统资源限制 | 可创建大量实例 |

### Skynet的混合模型

Skynet采用"少量工作线程 + 大量协程"的混合模型：

```
工作线程1: ████████████████████████████████
协程:      A→B→C→A→D→B→C→A→D→B→C...

工作线程2: ████████████████████████████████  
协程:      E→F→G→E→H→F→G→E→H→F→G...
```

**优势:**
- 利用多核CPU性能
- 避免传统多线程的复杂性
- 支持大量并发连接

### 协程让出时机

协程在以下情况会主动让出CPU：
- `skynet.call()` - 等待其他服务回复
- `skynet.sleep()` - 主动休眠
- `socket.read()` - 等待网络IO
- 数据库查询 - 等待IO操作

---

## 消息传递机制

### 通信模型

Skynet采用纯消息传递的通信模型，服务间不共享内存：

```
服务A ──(消息)──→ 服务B
  ↑                 │
  └──(回复)─────────┘
```

### 消息类型

#### 单向消息 (send)
```lua
skynet.send(target, "lua", "command", data)
-- 发送后立即返回，不等待回复
```

#### 双向消息 (call)
```lua
local result = skynet.call(target, "lua", "query", params)
-- 发送后等待回复
```

### 消息处理

```lua
skynet.dispatch("lua", function(session, address, cmd, ...)
    if cmd == "ping" then
        skynet.ret(skynet.pack("pong"))
    elseif cmd == "query" then
        local result = process_query(...)
        skynet.ret(skynet.pack(result))
    end
end)
```

---

## 分布式架构

### 集群通信

Skynet通过cluster模块实现分布式：

```
节点A (登录服务器) ←→ 节点B (游戏服务器1) ←→ 节点C (游戏服务器2)
```

### 重要概念澄清

**常见误解:**
- ❌ uniqueservice = 单服务器架构
- ❌ newservice = 分布式架构

**正确理解:**
- ✅ uniqueservice = 单节点内的唯一实例
- ✅ newservice = 单节点内的多实例
- ✅ cluster = 真正的分布式通信

### 分布式配置

#### 集群配置文件
```lua
-- cluster.lua
return {
    login_server = "192.168.1.100:7001",
    game_server_1 = "192.168.1.101:7001",
    game_server_2 = "192.168.1.102:7001",
}
```

#### 节点配置
```lua
-- 节点配置文件
thread = 8                    -- 工作线程数
harbor = 1                    -- 节点ID
cluster = "./cluster.lua"     -- 集群配置
clustername = "login_server"  -- 节点名称
```

---

## 协程调度机制

### 调度模型

```
全局调度队列
┌─────────────────────────────────────┐
│ [协程A] [协程B] [协程C] [协程D] ... │
└─────────────────┬───────────────────┘
                  │ 负载均衡
         ┌────────┼────────┐
         ▼        ▼        ▼
    工作线程1  工作线程2  工作线程3
```

### 关键特性

#### 动态分配
- 协程不固定绑定到特定线程
- 根据负载情况动态分配
- 空闲线程自动获取待执行协程

#### 跨线程迁移
协程可以在不同线程间运行：
```
T1时刻: 协程A在工作线程1执行
T2时刻: 协程A让出CPU (等待IO)
T3时刻: 协程A在工作线程3执行 (可能换了线程)
```

#### 无竞态条件
通过以下机制避免资源竞争：
- 消息传递，不共享内存
- 协程状态跟随协程移动
- 原子性执行，不会中途被打断

### 🔒 **重要问题：工作线程间的资源竞争**

#### ❓ **您的担心是合理的！**

既然有多个工作线程，它们之间确实可能产生资源竞争。但Skynet通过巧妙的设计避免了这个问题：

#### 🛡️ **Skynet的安全设计机制**

##### 1. **消息队列的线程安全**
```c
// Skynet内部使用无锁队列或者原子操作
// 多个工作线程安全地从全局消息队列中获取协程
struct message_queue {
    // 使用原子操作保证线程安全
    atomic_int head;
    atomic_int tail;
    struct message messages[MAX_QUEUE];
};
```

##### 2. **协程状态完全隔离**
```
工作线程1     工作线程2     工作线程3
┌─────────┐  ┌─────────┐  ┌─────────┐
│协程A    │  │协程C    │  │协程E    │
│├状态A   │  │├状态C   │  │├状态E   │
│└数据A   │  │└数据C   │  │└数据E   │
│协程B    │  │协程D    │  │协程F    │
│├状态B   │  │├状态D   │  │├状态F   │
│└数据B   │  │└数据D   │  │└数据F   │
└─────────┘  └─────────┘  └─────────┘

关键：每个协程的状态和数据完全独立！
```

##### 3. **消息传递的内存复制**
```lua
-- 发送消息时，Skynet会复制数据
local data = {player_id = 123, level = 50}
skynet.send(other_service, "lua", "update", data)

-- 接收方收到的是数据的副本，不是原始引用
-- 即使两个协程在不同线程运行，也不会有共享内存问题
```

##### 4. **Lua虚拟机的隔离**
```
每个协程都有独立的Lua执行栈：

工作线程1执行协程A时：
├── Lua栈A (独立)
├── 局部变量A (线程私有)
└── 协程上下文A (跟随协程)

工作线程2执行协程B时：
├── Lua栈B (独立)  
├── 局部变量B (线程私有)
└── 协程上下文B (跟随协程)

不存在共享的Lua状态！
```

#### 🔍 **具体的安全机制分析**

##### 可能的竞争点vs实际的保护机制：

| 潜在竞争点 | Skynet的保护机制 |
|------------|------------------|
| **全局消息队列** | 使用无锁队列或原子操作 |
| **协程调度** | 每个协程状态完全独立 |
| **内存分配** | 每个协程独立的内存空间 |
| **Lua虚拟机** | 每个协程独立的执行栈 |
| **服务地址分配** | 原子操作分配唯一ID |
| **消息传递** | 数据复制，不共享引用 |

##### 实际代码示例：
```lua
-- === 协程A (在工作线程1) ===
local function service_a()
    local my_data = {count = 0}  -- 线程1的栈空间
    
    while true do
        my_data.count = my_data.count + 1
        skynet.sleep(10)
        -- 即使下次在线程2执行，my_data也会跟随协程移动
    end
end

-- === 协程B (在工作线程2) ===  
local function service_b()
    local my_data = {count = 100}  -- 完全独立的数据
    
    while true do
        my_data.count = my_data.count - 1
        skynet.sleep(10)
        -- 与协程A的my_data完全无关！
    end
end

-- 两个协程即使在不同线程运行，也不会互相影响
```

#### ⚠️ **仍需注意的边界情况**

虽然Skynet设计得很安全，但仍有少数需要注意的地方：

##### 1. **全局变量的使用**
```lua
-- ❌ 危险：使用全局变量
global_counter = 0

skynet.start(function()
    global_counter = global_counter + 1  -- 可能有问题！
end)

-- ✅ 安全：使用消息传递
skynet.start(function()
    local counter_service = skynet.uniqueservice("counter")
    skynet.call(counter_service, "lua", "increment")
end)
```

##### 2. **C扩展模块的使用**
```lua
-- ❌ 危险：C扩展如果有全局状态
local cmodule = require "unsafe_c_module"
cmodule.set_global_value(123)  -- 可能被其他线程修改

-- ✅ 安全：确保C模块是线程安全的
local safe_cmodule = require "thread_safe_c_module"
safe_cmodule.process_data(data)
```

##### 3. **文件操作**
```lua
-- ❌ 潜在问题：多个协程写同一文件
local file = io.open("shared.txt", "w")
file:write("data from service A")

-- ✅ 更好：通过专门的日志服务
local logger = skynet.uniqueservice("logger")
skynet.send(logger, "lua", "write", "data from service A")
```

#### 🎯 **总结回答您的问题**

**您的担心是有道理的，但Skynet已经很好地解决了这个问题：**

1. **协程层面：** 完全隔离，无竞争
2. **线程层面：** 通过消息队列的原子操作和数据复制，避免竞争
3. **系统层面：** 不使用共享内存，只使用消息传递

**核心原则：**
```
Share Nothing + Message Passing = 无竞争
不共享任何状态 + 消息传递通信 = 线程安全
```

**但仍需注意：**
- 避免使用全局变量
- 确保C扩展的线程安全性
- 通过专门服务处理共享资源

这就是为什么Skynet能够轻松支持几万个协程而不出现并发问题的原因！

---

## 最佳实践

### 服务设计原则

#### 1. 保持服务轻量级
```lua
-- 好的做法：专一职责
skynet.start(function()
    -- 只处理玩家相关逻辑
end)

-- 避免：一个服务做太多事情
```

#### 2. 合理选择服务类型
```lua
-- 多实例：每个玩家一个代理
local player_agent = skynet.newservice("player_agent", player_id)

-- 单例：全局管理器
local db_mgr = skynet.uniqueservice("db_manager")
```

#### 3. 正确处理错误
```lua
local function safe_call(service, cmd, ...)
    local ok, result = pcall(skynet.call, service, "lua", cmd, ...)
    if not ok then
        skynet.error("Call failed:", result)
        return nil
    end
    return result
end
```

### 性能优化

#### 1. 减少不必要的消息传递
```lua
-- 避免频繁的小消息
for i = 1, 1000 do
    skynet.send(service, "lua", "update", i)  -- 不好
end

-- 批量处理
skynet.send(service, "lua", "batch_update", data_list)  -- 更好
```

#### 2. 合理使用缓存
```lua
-- 在服务内缓存频繁访问的数据
local cache = {}
local function get_player_data(player_id)
    if not cache[player_id] then
        cache[player_id] = load_from_db(player_id)
    end
    return cache[player_id]
end
```

#### 3. 避免阻塞操作
```lua
-- 不好：同步等待
local result = blocking_operation()

-- 好：异步处理
skynet.fork(function()
    local result = blocking_operation()
    -- 处理结果
end)
```

### 架构设计

#### 垂直扩展 (单节点优化)
```lua
-- 增加工作线程数
thread = 16

-- 创建多个工作服务
for i = 1, cpu_count do
    local worker = skynet.newservice("worker", i)
end
```

#### 水平扩展 (多节点)
```lua
-- 负载均衡到不同节点
local server_list = {"game1", "game2", "game3"}
local target = server_list[hash(player_id) % #server_list + 1]
cluster.send(target, "player_mgr", "create_player", player_data)
```

---

*核心概念文档 v1.0*  
*更新日期：2025年8月19日*
