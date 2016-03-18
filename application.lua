#!            /usb/bin/env/tarantool
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

    local fc = conn:execute('SELECT COUNT(*) AS forum FROM Forum')[1].forum
    local tc = conn:execute('SELECT COUNT(*) AS thread FROM Thread')[1].thread
    local pc = conn:execute('SELECT COUNT(*) AS post FROM Post')[1].post
    local uc = conn:execute('SELECT COUNT(*) AS user FROM User')[1].user

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
    conn:execute('TRUNCATE TABLE User;')
    conn:execute('TRUNCATE TABLE Forum;')
    conn:execute('TRUNCATE TABLE Post;')
    conn:execute('TRUNCATE TABLE Thread;')
    conn:execute('TRUNCATE TABLE Followers;')
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

    local user = {}
    if not pcall(function() user = req:json() end) then
        return req:render({ json = errorRequest(2) })
    end

    if user.email == nil
            or user.username == nil
            or user.about == nil
            or user.name == nil then
        return req:render({ json = errorRequest(3) })
    end
    local query = string.format('INSERT INTO User (username, about, name, email, isAnonymous) VALUES (%q, %q, %q, %q, %s)',
        user.username, user.about, user.name, user.email, user.isAnonymous)
    conn:execute(query)
    local created_user = conn:execute(string.format('select * from User where email = %q', user.email ))

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