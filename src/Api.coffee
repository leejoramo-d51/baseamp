util      = require "util"
request   = require "request"
moment    = require "moment"
_         = require "underscore"
debug     = require("debug")("Baseamp:Todo")
Util      = require "./Util"
fs        = require "fs"
async     = require "async"
TodoLists = require "./TodoLists"
TodoList  = require "./TodoList"

class Api
  vcr      : false
  endpoints:
    get_people: "https://basecamp.com/{{{account_id}}}/api/v1/people.json"
    get_lists : "https://basecamp.com/{{{account_id}}}/api/v1/projects/{{{project_id}}}/todolists.json"
    post_lists: "https://basecamp.com/{{{account_id}}}/api/v1/projects/{{{project_id}}}/todolists.json"
    put_lists : "https://basecamp.com/{{{account_id}}}/api/v1/projects/{{{project_id}}}/todolists/{{{item_id}}}.json"
    post_todos: "https://basecamp.com/{{{account_id}}}/api/v1/projects/{{{project_id}}}/todolists/{{{item_id}}}/todos.json"
    put_todos : "https://basecamp.com/{{{account_id}}}/api/v1/projects/{{{project_id}}}/todos/{{{item_id}}}.json"

  # I'm suspecting that we need to maintain order when
  # updating position on (automatically) many todos in a list
  uploadConcurrency  : 1
  downloadConcurrency: 32

  constructor: (config) ->
    @config = config || {}

    if !@config.username?
      throw new Error "Need a username"
    if !@config.password?
      throw new Error "Need a password"
    if !@config.account_id?
      throw new Error "Need a account_id"
    if !@config.project_id?
      throw new Error "Need a project_id"
    if !@config.fixture_dir?
      @config.fixture_dir = "#{__dirname}/../test/fixtures"

  _itemIdMatch: (type, displayField, item, remoteIds) ->
    # Save remote list IDs to local missing/broken ones
    # Match by unique name
    if !item.id || !remoteIds[type][item.id]?
      # this ID might be improved
      remoteItemsWithSameName = (remoteItem for remoteId, remoteItem of remoteIds[type] when remoteItem[displayField] == item[displayField])

      # update last item with identical name/content
      if remoteItemsWithSameName.length
        item.id = remoteItemsWithSameName[remoteItemsWithSameName.length - 1].id

    if item.id && !remoteIds[type][item.id]?
      # clear it, as we probably made a local typo and we don't want remote 404s
      item.id = undefined

    # Cascade possible change down onto todos
    if type == "lists"
      for todo in item.todos
        todo.todolist_id = item.id

    return item

  _assigneeToCallsign: (assignee, remoteIds) ->
    if !assignee?
      return undefined

    if assignee.callsign?
      return assignee.callsign

    if assignee.name?
      return Util.formatNameAsUnixHandle assignee.name

    if assignee.id?
      throw new Error "#{assignee.id}"

      return remoteIds.people[assignee.id].callsign

    if "#{assignee}".toUpperCase().substr(0, 3) == assignee
      return assignee

    throw new Error "Panic! Not sure how to handle assignee translation"

  _personIdMatch: (callsign, remoteIds) ->
    for id, person of remoteIds.people
      if person.callsign == callsign
        assignee =
          id  : person.id
          name: person.name
          type: "Person"
        return assignee

  _uploadItems: (type, displayField, items, remoteIds, cb) ->
    errors = []
    pushed = 0

    q = async.queue (item, qCb) =>
      item       = @_itemIdMatch type, displayField, item, remoteIds
      remoteItem = remoteIds[type][item.id]
      method     = if remoteItem? then "put" else "post"
      payload    = item.apiPayload()

      # Map callsign with person ID
      if payload.assignee?
        payload.assignee = @_personIdMatch payload.assignee, remoteIds

      if method == "put" && !@_itemDiffs type, remoteItem, displayField, payload, remoteIds
        # debug "SKIP #{@_human type, payload, displayField}"
        return qCb()

      if !payload[displayField]
        debug "SKIP empty weird todo with id: #{payload?.id}"
        return qCb()

      debug "PUSH   #{@_human type, payload, displayField}"
      pushed++
      opts =
        method : method
        url    : @endpoints["#{method}_#{type}"]
        replace:
          item_id: item.id

      if method == "post" && type = "todos"
        opts.replace =
          item_id: item.todolist_id

      @_request opts, payload, (err, data) =>
        if err
          errors.push "Errors while #{opts.method} #{opts.url}. #{err}"
          return qCb()

        item.id = data.id

        qCb()
    , @uploadConcurrency

    q.drain = () =>
      if errors.length
        return cb errors.join("\n")

      cb null, pushed

    q.push items

  _human: (type, item, displayField) ->
    abbr = item[displayField].substr(0, 20)

    if abbr != item[displayField]
      abbr += "..."

    return "#{type} " + abbr

  _itemDiffs: (type, remoteItem, displayField, payload, remoteIds) ->
    diff = []
    for key, val of payload
      remVal = remoteItem[key]

      # Turn assignee into callsign
      if key == "assignee"
        val    = @_assigneeToCallsign val, remoteIds
        remVal = @_assigneeToCallsign remVal, remoteIds

      # Do not uncomplete remotely completed items as to allow
      # people to check off items online
      if key == "completed" && val == false && remVal && true
        continue

      if val != remVal
        debug "CHANGE #{@_human type, payload, displayField}. Payload's '#{key}' is '#{val}' while remoteItem's is '#{remVal}'"
        return true

    return false

  uploadTodoLists: (localLists, cb) ->
    remoteIds =
      lists : {}
      todos : {}
      people: {}

    stats = {}

    async.waterfall [
      (callback) =>
        @downloadPeople (err, people) =>
          if err
            return callback err

          for person in people
            remoteIds.people[person.id] = person

          callback null

      (callback) =>
        @downloadTodoLists (err, remoteLists) =>
          if err
            return callback err

          # Save flat remote items
          remoteTodoLists = new TodoLists remoteLists
          for list in remoteTodoLists.lists
            remoteIds["lists"][list.id] = list
            for todo in list.todos
              remoteIds["todos"][todo.id] = todo

          callback null

      (callback) =>
        @_uploadItems "lists", "name", localLists.lists, remoteIds, (err, pushed) =>
          stats.listsPushed = pushed
          callback err

      (callback) =>
        allTodos = []
        for list in localLists.lists
          for todo in list.todos
            if !todo
              return callback new Error "No todo!"
            if !todo.todolist_id?
              todo.todolist_id = list.id
            if !todo.todolist_id?
              debug util.inspect
                todo   : todo
                list_id: list.id
              return callback new Error "Todo's todolist_id should be known here!"

            allTodos.push todo

        @_uploadItems "todos", "content", allTodos, remoteIds, (err, pushed) =>
          stats.todosPushed = pushed
          callback(err)

    ], (err, res) =>
      cb err, stats

  downloadPeople: (cb) ->
    debug "INFO   Retrieving people..."
    callsigns = []
    @_request @endpoints["get_people"], null, (err, people) =>
      if err
        return cb err

      for person, i in people
        callsign = Util.formatNameAsUnixHandle person.name

        if callsign in callsigns
          return cb new Error "There are multiple people with the callsign '#{callsign}'. Please fix that first. "

        callsigns.push callsign
        people[i].callsign = callsign

      return cb null, people

  downloadTodoLists: (cb) ->
    debug "INFO   Retrieving todolists..."
    @_request @endpoints["get_lists"], null, (err, lists) =>
      if err
        return cb err

      # Determine lists to retrieve
      retrieveUrls = (list.url for list in lists when list.url?)
      if !retrieveUrls.length
        debug "INFO   Found no lists urls (yet)"
        return cb null, []

      # The queue worker to retrieve the lists
      errors = []
      lists  = []
      q = async.queue (url, callback) =>
        @_request url, null, (err, todoList) ->
          if err
            errors.push "Error retrieving #{url}. #{err}"
            return callback()

          lists.push todoList
          callback()
      , @downloadConcurrency

      q.push retrieveUrls

      # Return
      q.drain = ->
        if errors.length
          return cb errors.join('\n')

        cb null, lists

  _request: (opts, payload, cb) ->
    if _.isString(opts)
      opts =
        url: opts

    opts.url     = Util.template opts.url, @config, opts.replace
    opts.body    = payload
    opts.method ?= "get"
    opts.json   ?= true
    opts.auth   ?=
      username: @config.username
      password: @config.password
    opts.headers ?=
      "User-Agent": "Baseamp (https://github.com/kvz/baseamp)"

    if opts.url.substr(0, 7) == "file://"
      filename = opts.url.replace /^file\:\/\//, ""
      json     = fs.readFileSync Util.template(filename, @config)
      data     = JSON.parse json
      return cb null, data

    # debug "#{opts.method.toUpperCase()} #{opts.url}"
    request[opts.method] opts, (err, req, data) =>
      status = "#{req.statusCode}"

      if !status.match /[23][0-9]{2}/
        debug util.inspect
          method : "#{opts.method.toUpperCase()}"
          url    : opts.url
          err    : err
          status : status
          data   : data
          payload: payload
        msg = "Status code #{status} during #{opts.method.toUpperCase()} '#{opts.url}'"
        err = new Error msg
        return cb err, data


      if @vcr == true && opts.url.substr(0, 7) != "file://"
        debug "VCR: Recording #{opts.url} to disk so we can watch later : )"
        fs.writeFileSync Util.template(@_toFixtureFile(opts.url), @config),
          JSON.stringify(@_toFixture(data), null, 2)
      cb err, data

  _toFixtureVal: (val, key) ->
    newVal = _.clone val
    if _.isObject(newVal) || _.isArray(newVal)
      newVal = @_toFixture newVal
    else if key == "account_id"
      newVal = 11
    else if key == "url"
      newVal = "file://" + @_toFixtureFile(newVal)
    else if "#{key}".slice(-4) == "_url"
      newVal = "http://example.com/"
    else if _.isNumber(newVal)
      newVal = 22
    else if _.isBoolean(newVal)
      newVal = false
    # else if _.isString(newVal)
    #   newVal = "what up"

    return newVal

  _toFixture: (obj) ->
    newObj = _.clone obj
    if _.isObject(newObj)
      for key, val of newObj
        newObj[key] = @_toFixtureVal(val, key)
    else if _.isArray(newObj)
      for val, key in newObj
        newObj[key] = @_toFixtureVal(val, key)
    else
      newObj = @_toFixtureVal(newObj)

    return newObj

  _toFixtureFile: (url) ->
    parts     = url.split "/projects/"
    url       = parts.pop()
    filename  = "{{{fixture_dir}}}" + "/"
    filename += url.replace /[^a-z0-9]/g, "."
    return filename

module.exports = Api
