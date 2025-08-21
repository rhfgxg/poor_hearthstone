# Skynet API 参考手册

## 目录
1. [核心API](#核心api)
2. [服务管理](#服务管理)
3. [消息传递](#消息传递)
4. [定时器](#定时器)
5. [数据库操作](#数据库操作)
6. [网络相关](#网络相关)
7. [集群管理](#集群管理)
8. [配置管理](#配置管理)
9. [调试工具](#调试工具)

---

## 核心API

### skynet.start(func)
启动服务的主入口函数。

**参数：**
- `func` (function): 服务初始化函数

**示例：**
```lua
skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        -- 处理消息
    end)
end)
```

### skynet.exit()
退出当前服务。

**示例：**
```lua
skynet.exit()
```

### skynet.error(msg, ...)
输出错误日志。

**参数：**
- `msg` (string): 日志消息，支持格式化
- `...` (任意类型): 格式化参数

**示例：**
```lua
skynet.error("Player %d login failed: %s", player_id, reason)
```

### skynet.getenv(key)
获取环境变量。

**参数：**
- `key` (string): 环境变量名

**返回值：**
- (string): 环境变量值

**示例：**
```lua
local thread_count = skynet.getenv("thread")
```

### skynet.setenv(key, value)
设置环境变量。

**参数：**
- `key` (string): 环境变量名
- `value` (string): 环境变量值

**示例：**
```lua
skynet.setenv("daemon", "./skynet.pid")
```

---

## 服务管理

### skynet.newservice(name, ...)
创建新服务实例。

**参数：**
- `name` (string): 服务脚本名称
- `...` (任意类型): 传递给服务的参数

**返回值：**
- (integer): 服务地址ID

**示例：**
```lua
local worker = skynet.newservice("task_worker", worker_id, config)
```

### skynet.uniqueservice(name, ...)
创建或获取唯一服务。

**参数：**
- `name` (string): 唯一服务名称
- `...` (任意类型): 初始化参数（仅首次创建时使用）

**返回值：**
- (integer): 服务地址ID

**示例：**
```lua
local db_mgr = skynet.uniqueservice("db_manager")
```

### skynet.queryservice(name)
查询已存在的唯一服务。

**参数：**
- `name` (string): 唯一服务名称

**返回值：**
- (integer): 服务地址ID

**示例：**
```lua
local service = skynet.queryservice("config_manager")
```

### skynet.kill(service_id)
终止指定服务。

**参数：**
- `service_id` (integer): 服务地址ID

**示例：**
```lua
skynet.kill(worker_service)
```

### skynet.self()
获取当前服务地址。

**返回值：**
- (integer): 当前服务地址ID

**示例：**
```lua
local my_address = skynet.self()
```

### skynet.localname(name)
通过本地名称获取服务地址。

**参数：**
- `name` (string): 本地注册名称

**返回值：**
- (integer|nil): 服务地址ID

**示例：**
```lua
local launcher = skynet.localname(".launcher")
```

---

## 消息传递

### skynet.send(address, typename, ...)
发送消息（不等待回复）。

**参数：**
- `address` (integer): 目标服务地址
- `typename` (string): 消息类型
- `...` (任意类型): 消息内容

**示例：**
```lua
skynet.send(worker, "lua", "process_task", task_data)
```

### skynet.call(address, typename, ...)
发送消息并等待回复。

**参数：**
- `address` (integer): 目标服务地址
- `typename` (string): 消息类型
- `...` (任意类型): 消息内容

**返回值：**
- (任意类型): 服务回复的数据

**示例：**
```lua
local result = skynet.call(db_service, "lua", "query", sql)
```

### skynet.ret(msg, sz)
回复消息。

**参数：**
- `msg` (userdata): 打包后的消息数据
- `sz` (integer): 消息大小（可选）

**示例：**
```lua
skynet.ret(skynet.pack("success", data))
```

### skynet.response()
获取回复函数。

**返回值：**
- (function): 回复函数

**示例：**
```lua
local response = skynet.response()
-- 异步处理后回复
response(true, result)
```

### skynet.dispatch(typename, func)
注册消息处理函数。

**参数：**
- `typename` (string): 消息类型
- `func` (function): 处理函数

**示例：**
```lua
skynet.dispatch("lua", function(session, address, cmd, ...)
    if cmd == "ping" then
        skynet.ret(skynet.pack("pong"))
    end
end)
```

### skynet.pack(...)
打包消息数据。

**参数：**
- `...` (任意类型): 要打包的数据

**返回值：**
- (userdata, integer): 打包后的数据和大小

**示例：**
```lua
local msg, sz = skynet.pack("hello", 123, {key = "value"})
```

### skynet.unpack(msg, sz)
解包消息数据。

**参数：**
- `msg` (userdata): 打包的消息
- `sz` (integer): 消息大小

**返回值：**
- (任意类型): 解包后的数据

**示例：**
```lua
local str, num, tbl = skynet.unpack(msg, sz)
```

---

## 定时器

### skynet.timeout(time, func)
设置单次定时器。

**参数：**
- `time` (integer): 延迟时间（厘秒）
- `func` (function): 回调函数

**示例：**
```lua
skynet.timeout(100, function()
    skynet.error("Timer fired")
end)
```

### skynet.sleep(time)
暂停当前协程。

**参数：**
- `time` (integer): 暂停时间（厘秒）

**示例：**
```lua
skynet.sleep(100)  -- 暂停1秒
```

### skynet.now()
获取当前时间。

**返回值：**
- (integer): 当前时间（厘秒）

**示例：**
```lua
local current_time = skynet.now()
```

### skynet.time()
获取Unix时间戳。

**返回值：**
- (integer): Unix时间戳（秒）

**示例：**
```lua
local timestamp = skynet.time()
```

### skynet.starttime()
获取系统启动时间。

**返回值：**
- (integer): 启动时间（厘秒）

**示例：**
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
    password = "password"
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
local value = db:get("key")
db:set("key", "value")

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
    -- 处理连接
end)

-- 连接服务器
local id = socket.open("127.0.0.1", 8080)
socket.write(id, "Hello")
local data = socket.read(id)
socket.close(id)
```

### HTTP服务
```lua
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"

-- 启动HTTP服务器
local listen_socket = sockethelper.listen("0.0.0.0", 8001)
socket.start(listen_socket, function(id, addr)
    -- 处理HTTP请求
end)
```

---

## 集群管理

### cluster API
```lua
local cluster = require "skynet.cluster"

-- 连接集群节点
cluster.open("node1")

-- 调用远程服务
local result = cluster.call("node1", "service_name", "method", params)

-- 发送消息到远程服务
cluster.send("node1", "service_name", "method", params)
```

### 集群配置
```lua
-- cluster.lua 配置文件
return {
    node1 = "127.0.0.1:7001",
    node2 = "127.0.0.1:7002",
}
```

---

## 配置管理

### 常用配置项
```
thread = 8                  -- 工作线程数
harbor = 0                  -- 集群节点ID
start = "main"              -- 启动服务
bootstrap = "snlua bootstrap"  -- 引导服务
daemon = "./skynet.pid"     -- 守护进程PID文件
logger = nil                -- 日志服务
logpath = "."              -- 日志路径
```

---

## 调试工具

### skynet.trace()
开启/关闭消息跟踪。

**示例：**
```lua
skynet.trace()  -- 开启跟踪
```

### debug console
```lua
local console = require "skynet.debug"
console.start()  -- 启动调试控制台
```

### 内存统计
```lua
local memory = require "skynet.memory"
local info = memory.info()
```

### 性能分析
```lua
local profile = require "skynet.profile"
profile.start()
-- 执行代码
local result = profile.stop()
```

---

*API参考手册 v1.0*  
*更新日期：2025年8月19日*
