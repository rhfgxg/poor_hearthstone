-- service/worker/init.lua脚本

local skynet = require "skynet"

-- 消息响应函数表
local CMD = {}
-- 服务名
local worker_name = ""
-- 服务id
local worker_id = ""
-- 工钱
local money = 0
-- 是否在工作
local isworking = false

-- 每帧调用，一帧的时间是0.2秒
local function update(frame)
    if isworking then
        money = money + 1
        skynet.error(worker_name .. tostring(worker_id) .. ", money: " .. tostring(money))
    end
end

-- 定时器，每隔0.2秒调用一次update函数
local function timer()
    local stime = skynet.now()
    local frame = 0
    while true do
        frame = frame + 1
        local isok, err = pcall(update, frame)
        if not isok then
            skynet.error(err)
        end
        local etime = skynet.now()
        -- 保证0.2秒
        local waittime = frame * 20 - (etime - stime)
        if waittime <= 0 then
            waittime = 2
        end
        skynet.sleep(waittime)
    end
end


-- 初始化
local function init(name, id)
    worker_name = name
    worker_id = id
end

-- 开始工作
function CMD.start_work(source)
    isworking = true
end

-- 停止工作
function CMD.stop_work(source)
    isworking = false
end

-- 调用初始化函数，...是不定参数，会从skynet.newservice的第二个参数开始透传过来
init(...)

skynet.start(function ()
	-- 消息分发
    skynet.dispatch("lua", function (session, source, cmd, ...)
    	-- 从CMD这个表中查找是否有定义响应函数，如果有，则触发响应函数
        local func = CMD[cmd]
        if func then
            func(source, ...)
        end
    end)

	-- 启动定时器
    skynet.fork(timer)
end)
