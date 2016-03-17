#!    /usb/bin/env/tarantool
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

-- todo

--------------
-- Thread.
--------------

-- todo

local httpd = require('http.server')

local server = httpd.new('127.0.0.1', 8081)

-- Общие.
server:route({ path = BASE_PATH .. '/status' }, status)

-- Forum.
server:route({ path = FORUM_PATH }, getForum)
server:route({ path = FORUM_PATH .. '/create' }, createForum)
-- Post.
-- User.
-- Thread.
server:start()