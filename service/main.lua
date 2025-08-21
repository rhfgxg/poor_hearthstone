local skynet = require "skynet"
skynet.start(function()
	skynet.error("[start main] hello world")
	
	-- 创建一个工作服务
    local worker = skynet.newservice("worker")
    
    -- 调用工作服务
    local result = skynet.call(worker, "lua", "work", "task1")
    skynet.error("Result:", result)
	
	skynet.exit()
end)
