#!        /usb/bin/env/tarantool
box.cfg {}

local BASE_PATH = '/db/api'
local FORUM_PATH = BASE_PATH .. '/forum'
local POST_PATH = BASE_PATH .. '/post'
local USER_PATH = BASE_PATH .. '/user'
local THREAD_PATH = BASE_PATH .. '/thread'

local mysql = require('mysql')
local conn = mysql.connect({ host = localhost, user = 'root', password = 'root', db = 'technopark' })

local function newResponse(code, response)
    return {
        code = code,
        response = response
    }
end

local RESPONSES = {
    "запрашиваемый объект не найден",
    "невалидный запрос",
    "некоректный запрос",
    "неизвестная ошибка",
    "такой юзер уже существует"
}

local function errorRequest(code)
    return newResponse(code, RESPONSES[code])
end


--------------
-- Общие.
--------------
local function status(req)
    if req.method ~= 'GET' then
        return req:render({ json = errorRequest(3) })
    end

    local fc = conn:execute('select count(*) as forum from Forum')[1].forum
    local tc = conn:execute('select count(*) as thread from Thread')[1].thread
    local pc = conn:execute('select count(*) as post from Post')[1].post
    local uc = conn:execute('select count(*) as user from User')[1].user

    local response = newResponse(0,
        {
            user = uc,
            thread = tc,
            forum = fc,
            post = pc,
        })
    return req:render({ json = response })
end

local function clear(req)
    if req.method ~= 'GET' then
        return req:render({ json = errorRequest(3) })
    end
    conn:execute('SET FOREIGN_KEY_CHECKS = 0;')
    conn:execute('truncate table User')
    conn:execute('truncate table Forum')
    conn:execute('truncate table Post')
    conn:execute('truncate table Thread')
    conn:execute('truncate table Followers')
    conn:execute('SET FOREIGN_KEY_CHECKS = 1;')
    local response = newResponse(0, 'OK')
    return req:render({ json = response })
end

--------------
-- Forum.
--------------
local function getForum(self)
    return self:render { json = conn:execute('select * from Forum;') }
end

local function createForum(req)
    local query = conn:execute('todo')[1].forum
    local response = {
        code = 0,
        response = {}
    }
    return req:render({ json = response })
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
local function createUser(req)
    if req.method ~= 'POST' then
        return req:render({ json = errorRequest(3) })
    end
    local json_req = {}
    if not pcall(function() json_req = req:json() end) then
        return req:render({ json = errorRequest(2) })
    end
    conn:execute('insert into User (username, about, name, email) values (\'' .. json_req.username .. '\',\'' .. json_req.about .. '\',\'' .. json_req.name .. '\',\'' .. json_req.email .. '\')')
    local created_user = conn:execute('select * from User where email = \'' .. json_req.email .. '\'')
    local response = {
        code = 0,
        response = created_user[1]
    }
    return req:render({ json = response })
end

--------------
-- Thread.
--------------

-- todo

local httpd = require('http.server')

local server = httpd.new('127.0.0.1', 8081)

-- Общие.
server:route({ path = BASE_PATH .. '/status' }, status)
server:route({ path = BASE_PATH .. '/clear' }, clear)

-- Forum.
server:route({ path = FORUM_PATH }, getForum)
server:route({ path = FORUM_PATH .. '/create' }, createForum)
-- Post.
-- User.
server:route({ path = USER_PATH .. '/create' }, createUser)
-- Thread.
server:start()