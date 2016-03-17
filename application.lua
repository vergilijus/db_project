#!      /usb/bin/env tarantool
box.cfg {}

local BASE_PATH = '/db/api'

local mysql = require('mysql')
local conn = mysql.connect({ host = localhost, user = 'root', password = 'root', db = 'technopark' })



--------------
-- Общие.
--------------
local function status(req)
    local fc = conn:execute('select count(*) as forum from Forum')[1].forum
    local tc = conn:execute('select count(*) as thread from Thread')[1].thread
    local pc = conn:execute('select count(*) as post from Post')[1].post
    local uc = conn:execute('select count(*) as user from User')[1].user

    local response = {
        code = 0,
        response = {
            user = uc,
            thread = tc,
            forum = fc,
            post = pc,
        }
    }
    return req:render({ json = response })
end

--------------
-- Forum.
--------------
local function getForum(self)
    return self:render { json = conn:execute('select * from Forum;') }
end

--------------
-- Post.
--------------
local function getPost(self)
    return self:render { json = conn:execute('select * from Post;') }
end

--------------
-- User.
--------------

-- todo

--------------
-- Thread.
--------------

-- todo

local httpd = require('http.server')

local server = httpd.new('127.0.0.1', 8081)
server:route({ path = BASE_PATH..'/forum' }, getForum)
server:route({ path = BASE_PATH..'/post' }, getPost)
server:route({ path = BASE_PATH..'/status' }, status)
server:start()