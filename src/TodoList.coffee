require("source-map-support").install()
util   = require "util"
moment = require "moment"
_      = require "underscore"
debug  = require("debug")("Baseamp:TodoList")
Todo   = require "./Todo"
Util   = require "./Util"

class TodoList
  constructor: (input, defaults) ->
    if !input?
      todoList = {}
    else if _.isString(input)
      todoList = @fromMarkdown(input)
    else
      todoList = @fromApi(input)

    _.defaults todoList, defaults

    @id       = todoList.id
    @name     = todoList.name
    @position = todoList.position
    @todos    = todoList.todos

  fromApi: (input) ->
    todoList =
      id   : input.id
      name : input.name
      todos: []

    for category, apiTodos of input.todos
      for apiTodo in apiTodos
        todo = new Todo apiTodo,
          todolist_id: todoList.id

        if todo?
          todoList.todos.push todo

    return todoList

  apiPayload: (update, endpoints) ->
    # Create
    opts =
      method: "post"
      url   : endpoints["todoLists"]

    payload =
      name: @name

    # Update
    if update
      opts.method  = "put"
      opts.url     = endpoints["todoList"]
      opts.replace =
        todolist_id: @id

      payload.position = @position

    ret =
      opts   :opts
      payload:payload

    return ret

  fromMarkdown: (str) ->
    todoList =
      todos: []

    str         = "#{str}".replace "\r", ""
    lines       = str.split "\n"
    cntPosition = 0
    for line in lines
      # Extract Header
      m = line.match /^##\s+(.+)$/
      if m
        {id, line}    = Util.extractId m[1]
        todoList.id   = id
        todoList.name = line
        continue

      # Ignore empty line
      if !line.trim()
        continue

      # Add todo
      cntPosition++
      todo = new Todo line,
        position   : cntPosition
        todolist_id: todoList.id
      if todo?
        todoList.todos.push todo

    return todoList

  toMarkdown: ->
    buf = "## #{@name} (##{@id})\n"
    buf += "\n"

    for todo in @todos
      buf += todo.toMarkdown()

    buf += "\n"

    return buf

module.exports = TodoList
