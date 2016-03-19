#!           /usb/bin/env/tarantool
box.cfg {}

local BASE_PATH = '/db/api'
local FORUM_PATH = BASE_PATH .. '/forum'
local POST_PATH = BASE_PATH .. '/post'
local USER_PATH = BASE_PATH .. '/user'
local THREAD_PATH = BASE_PATH .. '/thread'

local mysql = require('mysql')
local json = require('json')
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

local function errorResponse(code)
    return newResponse(code, RESPONSES[code])
end


--------------
-- Общие.
--------------
local function status(req)
    if req.method ~= 'GET' then
        return req:render({ json = errorResponse(3) })
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
        return req:render({ json = errorResponse(3) })
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
    return self:render {
        json = conn:execute('select * from Forum;')
    }
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
    return self:render {
        json = conn:execute('select * from Post;')
    }
end

--------------
-- User.
--------------
local function getUser(email)
    local user = conn:execute(string.format('SELECT * FROM User WHERE email = %q;', email))[1]
    if not user then return nil end

    user.followers = {}
    user.following = {}
    user.subscriptions = {}
    for key, val in pairs(user) do
        if val == '' then user[key] = json.null end
    end

    return user
end

local function createUser(req)
    -- Проверка метода.
    if req.method ~= 'POST' then
        return req:render({ json = errorResponse(3) })
    end

    -- Проверка валидности json.
    local user
    if not pcall(function() user = req:json() end) then
        return req:render({ json = errorResponse(2) })
    end

    -- Проверка обязательных параметров.
    if user.email == nil then
        return req:render({ json = errorResponse(3) })
    end

    -- Формируем запрос.
    local query
    if user.isAnonymous then
        query = string.format([[
        INSERT INTO User (email, isAnonymous)
        VALUES (%q, %s)
        ]], user.email, user.isAnonymous)
    else
        query = string.format([[
        INSERT INTO User (email, username, about, name)
        VALUES (%q, %q, %q, %q)
        ]], user.email, user.username, user.about, user.name)
    end

    -- ВЫполняем запрос, проверяем результат.
    local result, status = conn:execute(query)
    if not result then
        return req:render({ json = errorResponse(5) })
    end

    -- Получаем созданного пользователя.
    query = string.format('SELECT * FROM User WHERE EMAIL = %q', user.email)
    local created_user = conn:execute(query)[1]
    return req:render({ json = newResponse(0, created_user) })
end

local function userDetails(req)
    -- check method
    if req.method ~= 'GET' then
        return req:render({ json = errorResponse(3) })
    end


    local email = req:param('user')
    if email == nil then
        return req:render({ json = errorResponse(2) })
    end
    
    local details = getUser(email)
    if not details then
        return req:render({ json = errorResponse(1) })
    end

    local response = newResponse(0, details)
    return req:render({ json = response })
end

local function updateProfile(req)
    if req.method ~= 'POST' then
        return req:render({ json = errorResponse(3) })
    end

    -- Проверка валидности json.
    local user
    if not pcall(function() user = req:json() end) then
        return req:render({ json = errorResponse(2) })
    end

    -- Проверка обязательных параметров.
    if not user
            or not user.about
            or not user.name
            or not user.user then
        return req:render({ json = errorResponse(3) })
    end

    -- Формируем запрос.
    local query
    query = string.format([[
    UPDATE User SET name = %q, about = %q WHERE email = %q;]],
        user.name, user.about, user.user)

    -- Выполняем запрос.
    local result, status = conn:execute(query)
    if not result or status == 0 then
        return req:render({ json = errorResponse(1) })
    end

    -- Получаем обновленного пользователя.
    local created_user = getUser(user.user)
    return req:render({ json = newResponse(0, created_user) })
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
server:route({ path = USER_PATH .. '/details' }, userDetails)
server:route({ path = USER_PATH .. '/updateProfile' }, updateProfile)
-- Thread.
server:start()