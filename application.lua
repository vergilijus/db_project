#!                                  /usr/bin/env tarantool
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


local function getValues(tbl)
    local keys = {}
    local values = {}
    for k, v in pairs(tbl) do
        table.insert(keys, k)
        table.insert(values, v)
    end
    return values
end


-----------------
-- Общие.
-----------------
local function status(req)

    local fc = conn:execute('SELECT COUNT(*) AS forum FROM Forum')[1].forum
    local tc = conn:execute('SELECT COUNT(*) AS thread FROM Thread')[1].thread
    local pc = conn:execute('SELECT COUNT(*) AS post FROM Post')[1].post
    local uc = conn:execute('SELECT COUNT(*) AS user FROM User')[1].user

    return newResponse(0,
        {
            user = uc,
            thread = tc,
            forum = fc,
            post = pc,
        })
end


local function clear(req)
    conn:execute('SET FOREIGN_KEY_CHECKS = 0;')
    conn:execute('TRUNCATE TABLE User;')
    conn:execute('TRUNCATE TABLE Forum;')
    conn:execute('TRUNCATE TABLE Post;')
    conn:execute('TRUNCATE TABLE Thread;')
    conn:execute('TRUNCATE TABLE Followers;')
    conn:execute('SET FOREIGN_KEY_CHECKS = 1;')
    return newResponse(0, 'OK')
end

--------------
-- Forum.
--------------
local function getForum(self)
    return self:render {
        json = conn:execute('select * from Forum;')
    }
end


local function createForum(json_params)
    -- Проверяем параметры.
    if not checkReqParam(json_params, { 'name', 'short_name', 'user' }) then
        return errorResponse(3)
    end
    local forum = json_params
    -- Формируем запрос.
    local query = string.format([[
        INSERT INTO Forum (name, short_name, user)
        VALUES (%q, %q, %q)]], forum.name, forum.short_name, forum.user)
    local _, status = conn:execute(query)

    -- Получаем созданный форум.
    query = string.format([[
        SELECT id, name, short_name, user
        FROM Forum WHERE short_name = %q]], forum.short_name)
    local created_forum = conn:execute(query)[1]

    if not created_forum
            or created_forum.name ~= forum.name
            or created_forum.user ~= forum.user then
        return newResponse(4, status)
    end

    return newResponse(0, created_forum)
end


local function forumDetails(json_params)

    -- Проверяем параметры.
    local short_name = json_params.forum
    if not short_name then
        return errorResponse(2)
    end

    -- Формируем запрос.
    local query = string.format([[
    SELECT * FROM Forum WHERE short_name = %q]], short_name)

    local forum = conn:execute(query)[1]
    if not forum then
        return errorResponse(1)
    end

    if json_params.related == 'user' then
        forum.user = getUser(forum.user)
    end
    return newResponse(0, forum)
end

--------------
-- Post.
--------------
local function getPost(self)
    return self:render {
        json = conn:execute('select * from Post;')
    }
end

local function createPost(json_params)

    -- Проверка обязательных параметров.
    local req_params = { 'date', 'thread', 'message', 'user', 'forum' }
    if not checkReqParam(json_params, req_params) then errorResponse(3) end

    local fields = ''
    local values = ''
    for k, v in pairs(json_params) do
        fields = fields .. string.format('%s,', k)
        values = values .. '?,'
    end
    fields = string.sub(fields, 1, -2)
    values = string.sub(values, 1, -2)
    local query = string.format('INSERT INTO Post (%s) VALUES (%s)', fields, values)
    --    values = getPairs(json_params)
    local val = getValues(json_params)
    conn:begin()
    local result, status = conn:execute(query, unpack(val))
    if not result then
        conn:rollback()
        return newResponse(4, status)
    end
    local created_post, status = conn:execute('SELECT * FROM Post WHERE id = last_insert_id()')
    conn:commit()
    if not created_post then return newResponse(4, status) end
    --    local created_user = conn:execute('SELECT * FROM Post WHERE EMAIL = ?', post.email)[1]
    return newResponse(0, created_post)
end

local function postDetails(json_params)
    if not json_params.post then return errorResponse(3) end
    local post, status = conn:execute('SELECT * FROM Post WHERE id = ?', json_params.post)[1]
    if json_params.related then
        for k, v in pairs(json_params.related) do
            if v == 'user' then
                post.user = getUser(post.user)
            end
            if v == 'thread' then
                post.thread = conn:execute('SELECT * FROM Thread WHERE id = ?', post.thread)
            end
            if v == 'forum' then
                post.forum = conn:execute('SELECT * FROM Forum WHERE short_name = ?', post.forum)
            end
        end
    end

    return newResponse(0, post)
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


local function userDetails(json_params)

    local email = json_params.user
    if not email then
        return errorResponse(2)
    end
    local details = getUser(email)
    if not details then
        return errorResponse(1)
    end
    return newResponse(0, details)
end


local function updateProfile(json_params)
    -- Проверка обязательных параметров.
    if not checkReqParam(json_params, { 'about', 'name', 'user' }) then
        return errorResponse(3)
    end
    local user = json_params
    -- Формируем запрос.
    local query
    query = string.format([[
    UPDATE User SET name = %q, about = %q WHERE email = %q;]],
        user.name, user.about, user.user)

    -- Выполняем запрос.
    local result, status = conn:execute(query)
    if not result or status == 0 then
        return errorResponse(1)
    end

    -- Получаем обновленного пользователя.
    local created_user = getUser(user.user)
    return newResponse(0, created_user)
end

--------------
-- Thread.
--------------
local function createThread(json_params)

    -- Проверка обязательных параметров.
    if not checkReqParam(json_params, { 'forum', 'title', 'isClosed', 'user', 'date', 'message', 'slug' }) then
        return errorResponse(3)
    end
    local thread = json_params
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
        return newResponse(4, status1)
    end
    return newResponse(0, created_thread[1])
end


local function threadDetails(json_params)

    --    local id = req:param('thread')
    local params = json_params
    if not params.thread then
        return errorResponse(2)
    end

    local query = string.format([[
        SELECT * FROM Thread WHERE id = %d]], params.thread)
    local thread, status = conn:execute(query)
    thread = thread[1]
    if not thread or status == 0 then
        return errorResponse(1)
    end

    local related = params.related
    if not related then
        return newResponse(0, thread)
    end

    if type(related) == 'string' then
        thread = add_related(related, thread)
    else
        for _, v in pairs(related) do
            thread = add_related(v, thread)
        end
    end
    return newResponse(0, thread)
end


--------------
-- Server.
--------------

local httpd = require('http.server')

local server = httpd.new('127.0.0.1', 8081)


local function test(json_params)
    log.info('_handler')
    --    if not checkReqParam(json_params, { 'a', 'b', 'c' }) then return errorResponse(3) end
    return newResponse(0, 'ok')
end

server:hook('before_dispatch', function(self, request)
    log.info('_hook: before_dispatch')
    local json_params
    --    if true then
    --        return { response = request:query_param(nil) }
    --    end
    if request.method == 'GET' then
        json_params = decode(request.query)
    elseif request.method == 'POST' then
        if not pcall(function() json_params = request:json()
        end) then
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
server:route({ path = THREAD_PATH .. '/details', method = 'GET' }, threadDetails)
-- Errors.
server:route({ path = BASE_PATH .. '/error/object_not_found' }, notFound)
server:route({ path = '/invalid_request' }, invalidRequest)
-- Test.
server:route({ path = '/test' }, test)
server:route({ path = '/redir' }, error_redirect)

server:start()