#!               /usr/bin/env tarantool
box.cfg {
    log_level = 10,
    logger = '/home/gantz/tarantool_db_api.log'
}

local BASE_PATH = '/db/api'
local FORUM_PATH = BASE_PATH .. '/forum'
local POST_PATH = BASE_PATH .. '/post'
local USER_PATH = BASE_PATH .. '/user'
local THREAD_PATH = BASE_PATH .. '/thread'

local mysql = require('mysql')
local json = require('json')
local conn = mysql.connect({ host = localhost, user = 'root', password = 'root', db = 'technopark' })
local log = require('log')

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
local INSERT = 'INSERT INTO %s (%s) VALUES (%s)'

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
            if type(tmp) == 'table' then
                for k, v in pairs(tmp) do
                    table.insert(cgi[name], v)
                end
            else
                table.insert(cgi[name], tmp)
            end
        else
            cgi[name] = value
        end
    end
    return cgi
end

local function add_related(s, obj)
    if s == 'user' then
        obj.user = getUser(obj.user)
    end
    if s == 'forum' then
        local query = string.format('SELECT * FROM Forum WHERE short_name = %q', obj.forum)
        obj.forum = conn:execute(query)[1]
    end
    return obj
end

local function commaConcat(obj)
    local params = ''
    for _, v in pairs(obj) do
        params = params .. v .. ','
    end
    return string.sub(params, 1, -2)
end

local function fieldsToString(req, opt)
    local params = ''
    for _, v in pairs(req) do
        params = params .. v .. ','
    end
    for _, v in pairs(opt) do
        params = params .. v .. ','
    end
    return string.sub(params, 1, -2)
end

local function valuesToString(req, opt, obj)
    local s = '%q'
    for _, v in pairs(req) do
        s = string.format(s, obj[v]) .. ',%q'
    end

    for _, v in pairs(opt) do
        local cur_value = 'DEFAULT'
        if obj[v] then
            cur_value = obj[v]
        end
        s = string.format(s, cur_value) .. ',%q'
    end
    return string.sub(s, 1, -4)
end

local function checkReqParam(json_params, param_list)
    for k, v in pairs(param_list) do
        if not json_params[v] then return false end
    end
    return true
end

-----------------
-- Общие.
-----------------
local function status(req)

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

    -- Проверка валидности json.
    local forum
    if not pcall(function() forum = req:json()
    end) then
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

local function createPost(req)

    -- Проверка валидности json.
    local post
    if not pcall(function() post = req:json()
    end) then
        return req:render({ json = errorResponse(2) })
    end
    -- Проверка обязательных параметров.
    local req_params = { 'date', 'thread', 'message', 'user', 'forum' }
    local opt_params = { 'parent', 'isApproved', 'isHighlighted', 'isEdited', 'isSpam', 'isDeleted' }

    for _, v in pairs(req_params) do
        if not post[v] then return req:render({ json = errorResponse(3) })
        end
    end


    -- Формируем запрос.
    local query = string.format(INSERT, 'Post', valuesToString())
    if post.isAnonymous then
        query = string.format([[
        INSERT INTO User (email, isAnonymous)
        VALUES (%q, %s)
        ]], post.email, post.isAnonymous)
    else
        query = string.format([[
        INSERT INTO User (email, username, about, name)
        VALUES (%q, %q, %q, %q)
        ]], post.email, post.username, post.about, post.name)
    end

    -- ВЫполняем запрос, проверяем результат.
    local result, status = conn:execute(query)
    if not result then
        return req:render({ json = errorResponse(5) })
    end

    -- Получаем созданного пользователя.
    query = string.format('SELECT * FROM User WHERE EMAIL = %q', post.email)
    local created_user = conn:execute(query)[1]
    return req:render({ json = newResponse(0, created_user) })
end

--------------
-- User.
--------------
local function createUser(json_params)

    local user = json_params
    -- Проверка обязательных параметров.
    if user.email == nil then
        return errorResponse(3)
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
        return errorResponse(5)
    end

    -- Получаем созданного пользователя.
    query = string.format('SELECT * FROM User WHERE EMAIL = %q', user.email)
    local created_user = conn:execute(query)[1]
    return newResponse(0, created_user)
end


local function userDetails(req)

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

    -- Проверка валидности json.
    local user
    if not pcall(function() user = req:json()
    end) then
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

    -- Проверка валидности json.
    local thread
    if not pcall(function() thread = req:json()
    end) then
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

    if type(related) == 'string' then
        thread = add_related(related, thread)
    else
        for _, v in pairs(related) do
            thread = add_related(v, thread)
        end
    end
    return req:render({ json = newResponse(0, thread) })
end

local httpd = require('http.server')

local server = httpd.new('127.0.0.1', 8081)


local function test(json_params)
    log.info('_handler')
    if not checkReqParam(json_params, {'a', 'b', 'c'}) then return errorResponse(3) end
    return newResponse(0, 'ok')
end

server:hook('before_dispatch', function(self, request)
    log.info('_hook: before_dispatch')
    local json_params
    if request.method == 'GET' then
        json_params = decode(request.query)
    elseif request.method == 'POST' then
        if not pcall(function() json_params = request:json() end) then
            return { response = errorResponse(2) }
        end
    end
    log.info(json_params)
    return json_params
end)

server:hook('after_dispatch', function(self, request, json_param, response_data)
    log.info('_hook: after_dispatch')
    return request:render({ json = response_data })
end)

--server:hook('before_routes', before_routes_hook)
--server:hook('after_dispatch', aftere_dispatch_hook)
-- Общие.
server:route({ path = BASE_PATH .. '/status', method = 'GET' }, status)
server:route({ path = BASE_PATH .. '/clear', method = 'GET' }, clear)
-- Forum.
server:route({ path = FORUM_PATH }, getForum)
server:route({ path = FORUM_PATH .. '/create', method = 'POST' }, createForum)
server:route({ path = FORUM_PATH .. '/details', method = 'GET' }, forumDetails)
-- Post.
server:route({ path = POST_PATH .. '/create', method = 'POST' }, createPost)
server:route({ path = POST_PATH .. '/details', method = 'GET' }, postDetails)
-- User.
server:route({ path = USER_PATH .. '/create', method = 'POST' }, createUser)
server:route({ path = USER_PATH .. '/details', method = 'GET' }, userDetails)
server:route({ path = USER_PATH .. '/updateProfile', method = 'POST' }, updateProfile)
-- Thread.
server:route({ path = THREAD_PATH .. '/create', method = 'POST' }, createThread)
--server:route({ path = THREAD_PATH .. '/details', method = 'GET' }, threadDetails)
-- Errors.
server:route({ path = BASE_PATH .. '/error/object_not_found' }, notFound)
server:route({ path = '/invalid_request' }, invalidRequest)
-- Test.
server:route({ path = '/test' }, test)
server:route({ path = '/redir' }, error_redirect)

server:start()