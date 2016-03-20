#!                                    /usb/bin/env/tarantool
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

-------------------
-- Вспомогательные.
-------------------
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

local function unescape(s)
    s = string.gsub(s, "+", " ")
    s = string.gsub(s, "%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end)
    return s
end

-- Парсер query_string.
local function decode(s)
    local cgi = {}
    for name, value in string.gfind(s, "([^&=]+)=([^&=]+)") do
        name = unescape(name)
        value = unescape(value)
        if cgi[name] then
            local tmp = cgi[name]
            cgi[name] = {}
            table.insert(cgi[name], value)
            table.insert(cgi[name], tmp)
        else
            cgi[name] = value
        end
    end
    return cgi
end

-----------------
-- Общие.
-----------------
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
    if req.method ~= 'POST' then
        return req:render({ json = errorResponse(3) })
    end

    -- Проверка валидности json.
    local forum
    if not pcall(function() forum = req:json() end) then
        return req:render({ json = errorResponse(2) })
    end

    -- Проверяем параметры.
    if not forum
            or not forum.name
            or not forum.short_name
            or not forum.user then
        return req:render({ json = errorResponse(3) })
    end

    -- Формируем запрос.
    local query = string.format([[
        INSERT INTO Forum (name, short_name, user)
        VALUES (%q, %q, %q)]], forum.name, forum.short_name, forum.user)
    local result, status = conn:execute(query)

    -- Получаем созданный форум.
    query = string.format([[
        SELECT id, name, short_name, user
        FROM Forum WHERE short_name = %q]], forum.short_name)
    local created_forum = conn:execute(query)[1]

    if not created_forum
            or created_forum.name ~= forum.name
            or created_forum.user ~= forum.user then
        return req:render({ json = newResponse(4, status) })
    end

    return req:render({ json = newResponse(0, created_forum) })
end


local function forumDetails(req)
    if req.method ~= 'GET' then
        return req:render({ json = errorResponse(3) })
    end

    -- Проверяем параметры.
    local short_name = req:param('forum')
    if not short_name then
        return req:render({ json = errorResponse(2) })
    end

    -- Формируем запрос.
    local query = string.format([[
    SELECT * FROM Forum WHERE short_name = %q]], short_name)

    local forum = conn:execute(query)[1]
    if not forum then
        return req:render({ json = errorResponse(1) })
    end

    if req:param('related') == 'user' then
        forum.user = getUser(forum.user)
    end
    return req:render({ json = newResponse(0, forum) })
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
    if not email then
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
local function createThread(req)
    if req.method ~= 'POST' then
        return req:render({ json = errorResponse(3) })
    end
    -- Проверка валидности json.
    local thread
    if not pcall(function() thread = req:json() end) then
        return req:render({ json = errorResponse(2) })
    end
    -- Проверка обязательных параметров.
    if not thread
            or not thread.forum
            or not thread.title
            or not thread.isClosed
            or not thread.user
            or not thread.date
            or not thread.message
            or not thread.slug then
        return req:render({ json = errorResponse(3) })
    end

    -- Формируем запрос.
    local query = string.format([[
        INSERT INTO Thread (forum, title, user, date, message, slug, isClosed)
        VALUES (%q, %q, %q, %q, %q, %q, %s) ]],
        thread.forum, thread.title, thread.user, thread.date, thread.message, thread.slug, thread.isClosed)

    local result, status1 = conn:execute(query)

    -- Получаем созданный тред.
    query = string.format([[
        SELECT * FROM Thread WHERE slug = %q]], thread.slug)
    local created_thread, status2 = conn:execute(query)
    if not created_thread or status2 == 0 then
        return req:render({ json = newResponse(4, status1) })
    end
    return req:render({ json = newResponse(0, created_thread[1]) })
end


local function threadDetails(req)
    if req.method ~= 'GET' then
        return req:render({ json = errorResponse(3) })
    end

--    local id = req:param('thread')
    local params = decode(req.query)
    if not params.thread then
        return req:render({ json = errorResponse(2) })
    end

    local query = string.format([[
        SELECT * FROM Thread WHERE id = %d]], params.thread)
    local thread, status = conn:execute(query)
    thread = thread[1]
    if not thread or status == 0 then
        return req:render({ json = errorResponse(1) })
    end

    local related = params.related
    if not related then
        return req:render({ json = newResponse(0, thread) })
    end
    for _, v in pairs(related) do
        if v == 'user' then
            thread.user = getUser(thread.user)
        end
        if v == 'forum' then
            local query = string.format('SELECT * FROM Forum WHERE short_name = %q', thread.forum)
            thread.forum = conn:execute(query)[1]
        end
    end
    return req:render({ json = newResponse(0, thread) })
end

local httpd = require('http.server')

local server = httpd.new('127.0.0.1', 8081)

local function test(req)
    if req.method ~= 'GET' then
        return req:render({ json = errorResponse(3) })
    end
    local query_string = decode(req.query)
    return req:render({ json = newResponse(0, query_string) })
end

-- Общие.
server:route({ path = BASE_PATH .. '/status' }, status)
server:route({ path = BASE_PATH .. '/clear' }, clear)

-- Forum.
server:route({ path = FORUM_PATH }, getForum)
server:route({ path = FORUM_PATH .. '/create' }, createForum)
server:route({ path = FORUM_PATH .. '/details' }, forumDetails)
-- Post.
-- User.
server:route({ path = USER_PATH .. '/create' }, createUser)
server:route({ path = USER_PATH .. '/details' }, userDetails)
server:route({ path = USER_PATH .. '/updateProfile' }, updateProfile)
-- Thread.
server:route({ path = THREAD_PATH .. '/create' }, createThread)
server:route({ path = THREAD_PATH .. '/details' }, threadDetails)
-- Test.
server:route({ path = BASE_PATH .. '/test' }, test)
server:start()