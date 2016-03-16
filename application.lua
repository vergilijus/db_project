#! /usb/bin/env tarantool

box.cfg {}

local mysql = require('mysql')
local conn = mysql.connect({ host = localhost, user = 'root', password = 'root', db = 'technopark' })

local function getForum(self)
    return self:render { json = conn:execute('select * from Forum;') }
end

local function getPost(self)
    return self:render { json = conn:execute('select * from Post;') }
end

local function status(self)
    return self:render { json = conn:execute('select count(*) from Forum') }
end

local function test(self)
    return self:render { text = 'hello' }
end

local httpd = require('http.server')

local server = httpd.new('*', 8081)
server:route({ path = '/forum' }, getForum)
server:route({ path = '/post' }, getPost)
server:route({ path = '/status' }, status)
server:route({ path = '/test' }, test)
server:start()