local ltask = require "ltask"
local socket = require "lsocket"
local starre = require "starre"
local json = require "json"
local db = require "mongo"


local S = setmetatable({}, { __gc = function() print "Worker exit" end } )

local ID = ...
local network_efd
print("Worker init", ID)


local request = {}

function request:ping(params)
	return {start = params.now, now = socket.time()}
end

function request:playgame(params)
	print("----------------playgame----------------")
	if (self.gold - params.betnum < 0) then
		return {ok = false, msg = "金币不足"}
	end

	self.gold = self.gold - params.betnum
	dump(self)
	return {ok = true, gold = self.gold}
end


function request:roleinfo()
	return self
end
--------------------------------------------------------------------

-- data: `["ping", {"start":123}]`

function S.player_request(pid, data)
	local p <close> = starre.query("user@"..pid)
	local t = json.decode(data) 			
	local f = assert(request[t[1]], t[1])

	local r = f(p, t[2])
	if r and assert(type(r) == "table") then
		ltask.fork(function ()
			socket.ewrite(network_efd, 1)
		end)
		return json.encode(r)
	end
end


function S.player_login(pid, addr)
	local p = db.user.find_one{id = pid}
	if not p then
		p = {id = pid, gold = 50000, diamond = 500000}
		p._id = db.user.insert(p)
	end
	starre.new("user@"..pid, p)
end


function S.init(efd)
	network_efd = efd 
end


return S
