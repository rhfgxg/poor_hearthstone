local skynet = require "skynet"
skynet.start(function()
	skynet.error("[start main] hello world")
	
	-- TODO 启动其他服务
	
	skynet.exit()
end)
