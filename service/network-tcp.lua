local ltask = require "ltask"
local starre = require "starre"
local socket = require "lsocket"
local epoll = require "lepoll"
local newgate = require "gate"

local EPOLLIN_OR_EPOLLET <const> = epoll.EPOLLIN | epoll.EPOLLET


local S = setmetatable({}, { __gc = function() print "Network exit" end } )

print("Network init")




function S.start(workers)
	local epfd = assert(epoll.create())

	local efd = socket.eventfd()
	epoll.register(epfd, efd, EPOLLIN_OR_EPOLLET)

	for _,w in ipairs(workers) do
		ltask.call(w, "init", efd)
	end

	local listenfd = assert(socket.listen("127.0.0.1", 6666, socket.SOCK_STREAM))
	epoll.register(epfd, listenfd, EPOLLIN_OR_EPOLLET)
	print("Listen on 6666")

	local function close(fd)
		socket.close(fd)
		epoll.unregister(epfd, fd)
	end

	local gate = newgate({send = socket.send, close = close}, workers)

	------------------------------------------------------------
	local function accept()
		local fd, addr, err = socket.accept(listenfd)
		if fd then
			epoll.register(epfd, fd, EPOLLIN_OR_EPOLLET)
			gate.on_accept(fd, addr)
		else
			print("accept error", err)
		end
	end


	local function recv(fd)
		local msg, err = socket.recv(fd)
		if msg then
			gate.on_data(fd, msg)
		else
			print("recv error", err)
			if err == "closed" then
				close(fd)
				gate.on_close(fd)
			end
		end
	end


	ltask.fork(function ()
		while true do
			local events = epoll.wait(epfd, -1, 512)

			for fd,event in pairs(events) do
				if fd == efd then
					socket.eread(efd) 					-- only to wakeup network
				elseif fd == listenfd then
					accept(fd)
				else
					recv(fd)
				end
			end
			ltask.sleep(0)
		end
	end)
end



return S