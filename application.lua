#!/usb/bin/env tarantool

box.cfg{}

local mysql = require('mysql')
local conn = mysql.connect({host = localhost, user = 'root', password = 'root', db = 'technopark'})

local function handler(self)
    return self:render{ json = conn:execute('select * from Forum;') }
end

local httpd = require('http.server')
local server = httpd.new('*', 8081)
server:route({ path = '/'  }, handler)
server:start()