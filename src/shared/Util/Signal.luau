--!strict
-- Minimal in-process signal for communication between services or between controllers.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }

export type Signal = typeof(setmetatable({} :: { handlers: { [number]: (...any) -> () }, nextId: number }, Signal))

function Signal.new(): Signal
	return setmetatable({ handlers = {}, nextId = 0 }, Signal)
end

function Signal.Connect(self: Signal, handler: (...any) -> ()): Connection
	self.nextId += 1
	local id = self.nextId
	self.handlers[id] = handler
	local connection = {}
	function connection.Disconnect(_: Connection)
		self.handlers[id] = nil
	end
	return connection :: Connection
end

function Signal.Fire(self: Signal, ...: any)
	for _, handler in table.clone(self.handlers) do
		task.spawn(handler, ...)
	end
end

function Signal.DisconnectAll(self: Signal)
	table.clear(self.handlers)
end

return Signal
