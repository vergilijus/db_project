#!     /usr/bin/env tarantool

box.cfg {--    log_level = 10,
    --    logger = 'tarantool_db_api.log'
}

local BASE_PATH = '/db/api'
local FORUM_PATH = BASE_PATH .. '/forum'
local POST_PATH = BASE_PATH .. '/post'
local USER_PATH = BASE_PATH .. '/user'
local THREAD_PATH = BASE_PATH .. '/thread'

local log = require 'log'
local json = require 'json'
local mysql = require 'mysql'
local conn = mysql.connect({ host = localhost, raise = true, user = 'tp_user', password = 'qwerty', db = 'db_api' })

local PORT = 8081
local HOST = '*'


-- Common.
local clear -- https://github.com/andyudina/technopark-db-api/blob/master/doc/clear.md
local status -- https://github.com/andyudina/technopark-db-api/blob/master/doc/status.md
-- Forum.
local createForum -- https://github.com/andyudina/technopark-db-api/blob/master/doc/forum/create.md
local forumDetails -- https://github.com/andyudina/technopark-db-api/blob/master/doc/forum/details.md
-- User.
local createUser -- https://github.com/andyudina/technopark-db-api/blob/master/doc/user/create.md
local userDetails -- https://github.com/andyudina/technopark-db-api/blob/master/doc/user/details.md
local updateProfile -- https://github.com/andyudina/technopark-db-api/blob/master/doc/user/updateProfile.md
local follow -- https://github.com/andyudina/technopark-db-api/blob/master/doc/user/follow.md
local listFollowers -- https://github.com/andyudina/technopark-db-api/blob/master/doc/user/listFollowers.md
local listFollowing -- https://github.com/andyudina/technopark-db-api/blob/master/doc/user/listFollowing.md
local userListPosts -- https://github.com/andyudina/technopark-db-api/blob/master/doc/user/listPosts.md
local unfollow -- https://github.com/andyudina/technopark-db-api/blob/master/doc/user/unfollow.md

-- Post.
local createPost -- https://github.com/andyudina/technopark-db-api/blob/master/doc/post/create.md
local postDetails -- https://github.com/andyudina/technopark-db-api/blob/master/doc/post/details.md
local removePost -- https://github.com/andyudina/technopark-db-api/blob/master/doc/post/remove.md
-- Thread.
local createThread -- https://github.com/andyudina/technopark-db-api/blob/master/doc/thread/create.md
local threadDetails -- https://github.com/andyudina/technopark-db-api/blob/master/doc/thread/details.md

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
    local user = conn:execute('SELECT * FROM User WHERE email = ?', email)[1]
    if not user then return nil end
    user.followers = {}
    for _, v in pairs(conn:execute('SELECT follower FROM Followers WHERE followee = ?', email)) do
        table.insert(user.followers, v.follower)
    end
    user.following = {}
    for _, v in pairs(conn:execute('SELECT followee FROM Followers WHERE follower = ?', email)) do
        table.insert(user.following, v.followee)
    end
    user.subscriptions = {}
    for _, v in pairs(conn:execute('SELECT thread FROM Subscription WHERE user = ?', email)) do
        table.insert(user.subscriptions, v.thread)
    end
    return user
end

local function getUsers(emails)
    local users = conn:execute('')
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

local function keysPresent(obj, keys)
    if not obj then
        return false
    end
    for _, key in pairs(keys) do
        if obj[key] == nil and obj[key] ~= json.null then
            return false, key
        elseif obj[key] == json.null then
            obj[key] = nil
        end
    end
    return true
end

local function validRelated(related, values)
    if not related then return true end
    if type(related) == 'string' then
        for _, v in pairs(values) do
            if related == v then return true end
        end
        return false
    end
    if type(related) ~= 'table' or #related > #values then
        return false
    end
    local counter = #related
    for _, rel in pairs(related) do
        for _, val in pairs(values) do
            if rel == val then counter = counter - 1 end
        end
    end
    return counter == 0
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
status = function(req)

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

clear = function(req)
    conn:begin()
    conn:execute('SET FOREIGN_KEY_CHECKS = 0;')
    conn:execute('TRUNCATE TABLE User;')
    conn:execute('TRUNCATE TABLE Forum;')
    conn:execute('TRUNCATE TABLE Post;')
    conn:execute('TRUNCATE TABLE Thread;')
    conn:execute('TRUNCATE TABLE Followers;')
    conn:execute('SET FOREIGN_KEY_CHECKS = 1;')
    conn:commit()
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


createForum = function(params)
    -- Проверяем параметры.
    if not keysPresent(params, { 'name', 'short_name', 'user' }) then
        return errorResponse(3)
    end
    local forum = params
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

forumDetails = function(params)

    -- Проверяем параметры.
    local short_name = params.forum
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

    if params.related == 'user' then
        forum.user = getUser(forum.user)
    end
    return newResponse(0, forum)
end

--------------
-- Post.
--------------
local function getPost(id)
    local post = conn:execute('SELECT * FROM Post WHERE id = ?', id)[1]
    return post
end

createPost = function(params)

    -- Проверка обязательных параметров.
    local req_params = { 'date', 'thread', 'message', 'user', 'forum' }
    if not keysPresent(params, req_params) then errorResponse(3) end
    if params.parent == json.null then params.parent = nil end
    local fields = ''
    local values = ''
    for k, v in pairs(params) do
        fields = fields .. string.format('%s,', k)
        values = values .. '?,'
    end
    fields = string.sub(fields, 1, -2)
    values = string.sub(values, 1, -2)
    local query = string.format('INSERT INTO Post (%s) VALUES (%s)', fields, values)
    --    values = getPairs(json_params)
    local val = getValues(params)
    conn:begin()
    local result, status = conn:execute(query, unpack(val))
    local posts = conn:execute('UPDATE Thread SET posts = posts + 1')
    if not result then
        conn:rollback()
        return newResponse(4, status)
    end
    local created_post, status = conn:execute('SELECT * FROM Post WHERE id = last_insert_id()')
    conn:commit()
    if not created_post then return newResponse(4, status) end
    --    local created_user = conn:execute('SELECT * FROM Post WHERE EMAIL = ?', post.email)[1]
    return newResponse(0, created_post[1])
end

postDetails = function(json_params)
    if not json_params.post then return errorResponse(3) end
    local post, nrows = conn:execute('SELECT * FROM Post WHERE id = ?', json_params.post)
    if not post or nrows ~= 1 then
        return errorResponse(1)
    end
    post = post[1]
    if json_params.related then
        for k, v in pairs(json_params.related) do
            if v == 'user' then
                post.user = getUser(post.user)
            end
            if v == 'thread' then
                post.thread = conn:execute('SELECT * FROM Thread WHERE id = ?', post.thread)[1]
            end
            if v == 'forum' then
                post.forum = conn:execute('SELECT * FROM Forum WHERE short_name = ?', post.forum)[1]
            end
        end
    end

    return newResponse(0, post)
end

removePost = function(params)
    if not params.post then
        return errorResponse(3)
    end

    local result, nrows conn:execute('UPDATE Post SET isDeleted = TRUE WHERE id = ?', params.post)
    if not result or nrows == 0 then
        return errorResponse(1)
    end
    return newResponse(0, params)
end
--------------
-- User.
--------------
createUser = function(params)
    local user = params
    -- Проверка обязательных параметров.
    if not keysPresent(params, { 'username', 'about', 'name', 'email' }) then
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

    -- Выполняем запрос, проверяем результат.
    if not pcall(function() conn:execute(query) end) then
        return errorResponse(5)
    end

    -- Получаем созданного пользователя.
    query = string.format('SELECT * FROM User WHERE EMAIL = %q', user.email)
    local created_user = conn:execute(query)[1]
    return newResponse(0, created_user)
end

userDetails = function(json_params)

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

updateProfile = function(json_params)
    -- Проверка обязательных параметров.
    if not keysPresent(json_params, { 'about', 'name', 'user' }) then
        return errorResponse(3)
    end
    local user = json_params
    -- Формируем запрос.
    local query
    query = string.format([[
    UPDATE User SET name = %q, about = %q WHERE email = %q]],
        user.name, user.about, user.user)

    -- Выполняем запрос.
    local result, status = conn:execute(query)
    if not result then
        return errorResponse(1)
    end

    -- Получаем обновленного пользователя.
    local created_user = getUser(user.user)
    return newResponse(0, created_user)
end

follow = function(param)
    if not param.follower or not param.followee then
        return errorResponse(3)
    end
    pcall(function()
        conn:execute('INSERT INTO Followers (follower, followee) VALUES (?, ?)', param.follower, param.followee)
    end)
    local user = getUser(param.follower)
    if not user then
        return errorResponse(1)
    end
    return newResponse(0, user)
end

unfollow = function(param)
    if not param.follower or not param.followee then
        return errorResponse(3)
    end
    pcall(function()
        conn:execute('DELETE FROM Followers WHERE follower = ? and followee = ?', param.follower, param.followee)
    end)
    local user = getUser(param.follower)
    if not user then
        return errorResponse(1)
    end
    return newResponse(0, user)
end

listFollowers = function(param)
    if not param.user then return errorResponse(3) end
    if not getUser(param.user) then return errorResponse(1) end
    local followers = conn:execute('SELECT follower FROM Followers WHERE followee = ?', param.user)
    local list_followers = {}
    for k, v in pairs(followers) do
        table.insert(list_followers, getUser(v['follower']))
    end
    return newResponse(0, list_followers)
end

listFollowing = function(param)
    if not param.user then return errorResponse(3) end
    if not getUser(param.user) then return errorResponse(1) end
    local followees = conn:execute('SELECT followee FROM Followers WHERE follower = ?', param.user)
    local list_followees = {}
    for k, v in pairs(followees) do
        table.insert(list_followees, getUser(v['followee']))
    end
    return newResponse(0, list_followees)
end

userListPosts = function(param)
    if not param.user then return errorResponse(3) end
    if not getUser(param.user) then return errorResponse(1) end
    local list_posts = {}
    local result = conn:execute('SELECT * FROM Post WHERE user = ?', param.user)
    if result then list_posts = result end
    return newResponse(0, list_posts)
end

--------------
-- Thread.
--------------
createThread = function(json_params)

    --    if true then return newResponse(0, json_params) end
    -- todo
    --    if not keys_present(json_params, { 'forum', 'title', 'isClosed', 'user', 'date', 'message', 'slug' , 'isDeleted'}) then
    --        return errorResponse(3)
    --    end
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

threadDetails = function(params)
    if not params.thread
            or not validRelated(params.related, { 'user', 'forum' }) then
        return errorResponse(3)
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

local httpd = require 'http.server'
local server = httpd.new(HOST, PORT)


local function test(params)
    log.info('_handler')
    --    if not checkReqParam(json_params, { 'a', 'b', 'c' }) then return errorResponse(3) end
    --    conn:execute('someshit')
    return newResponse(0, params)
end

server:hook('before_dispatch', function(self, request)
    -- fixme: работают либо json параметры либо query_string
    log.info('_hook: before_dispatch')
    local params
    if request.method == 'GET' then
        params = request:query_param()
        --        params = decode(request.query)
    elseif request.method == 'POST' then
        if not pcall(function() params = request:json() end) then
            return { response = errorResponse(2) }
        end
    end
    log.info(params)
    return params
end)

server:hook('after_handler_error', function(self, request, params, error)
    log.info('_hook: after_handler_error')
    return newResponse(4, error)
end)

server:hook('after_dispatch', function(self, request, params, response_data)
    log.info('_hook: after_dispatch')
    return request:render({ json = response_data })
end)


-- Общие.
server:route({ path = BASE_PATH .. '/status', method = 'GET' }, status)
server:route({ path = BASE_PATH .. '/clear', method = 'POST' }, clear)
-- Forum.
server:route({ path = FORUM_PATH }, getForum)
server:route({ path = FORUM_PATH .. '/create', method = 'POST' }, createForum)
server:route({ path = FORUM_PATH .. '/details', method = 'GET' }, forumDetails)
-- Post.
server:route({ path = POST_PATH .. '/create', method = 'POST' }, createPost)
server:route({ path = POST_PATH .. '/details', method = 'GET' }, postDetails)
server:route({ path = POST_PATH .. '/remove', method = 'POST' }, removePost)
-- User.
server:route({ path = USER_PATH .. '/create', method = 'POST' }, createUser)
server:route({ path = USER_PATH .. '/details', method = 'GET' }, userDetails)
server:route({ path = USER_PATH .. '/updateProfile', method = 'POST' }, updateProfile)
server:route({ path = USER_PATH .. '/follow', method = 'POST' }, follow)
server:route({ path = USER_PATH .. '/unfollow', method = 'POST' }, unfollow)
server:route({ path = USER_PATH .. '/listFollowers', method = 'GET' }, listFollowers)
server:route({ path = USER_PATH .. '/listFollowing', method = 'GET' }, listFollowing)
server:route({ path = USER_PATH .. '/listPosts', method = 'GET' }, userListPosts)
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