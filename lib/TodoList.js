// Generated by CoffeeScript 1.7.1
(function() {
  var Todo, TodoList, Util, debug, moment, util, _;

  util = require("util");

  moment = require("moment");

  _ = require("underscore");

  debug = require("debug")("Baseamp:TodoList");

  Todo = require("./Todo");

  Util = require("./Util");

  TodoList = (function() {
    function TodoList(input, defaults) {
      var todoList;
      if (input == null) {
        todoList = {};
      } else if (_.isString(input)) {
        todoList = this.fromMarkdown(input);
      } else {
        todoList = this.fromApi(input);
      }
      _.defaults(todoList, defaults);
      if (todoList.id != null) {
        this.id = Number(todoList.id);
      }
      this.name = todoList.name;
      this.position = Number(todoList.position);
      this.todos = todoList.todos;
    }

    TodoList.prototype.fromApi = function(input) {
      var apiTodo, apiTodos, category, todo, todoList, _i, _len, _ref;
      todoList = {
        id: input.id,
        name: input.name,
        position: input.position,
        todos: []
      };
      _ref = input.todos;
      for (category in _ref) {
        apiTodos = _ref[category];
        for (_i = 0, _len = apiTodos.length; _i < _len; _i++) {
          apiTodo = apiTodos[_i];
          todo = new Todo(apiTodo, {
            todolist_id: todoList.id
          });
          if (todo != null) {
            todoList.todos.push(todo);
          }
        }
      }
      Util.sortByObjField(todoList.todos, "position");
      return todoList;
    };

    TodoList.prototype.apiPayload = function(item) {
      var payload;
      if (item == null) {
        item = this;
      }
      payload = {
        name: item.name,
        position: item.position
      };
      return payload;
    };

    TodoList.prototype.fromMarkdown = function(str) {
      var id, line, lines, m, position, todo, todoList, _i, _len, _ref;
      todoList = {
        todos: []
      };
      str = ("" + str).replace("\r", "");
      lines = str.split("\n");
      position = 0;
      for (_i = 0, _len = lines.length; _i < _len; _i++) {
        line = lines[_i];
        m = line.match(/^##\s+(.+)$/);
        if (m) {
          _ref = Util.extractId(m[1]), id = _ref.id, line = _ref.line;
          todoList.id = id;
          todoList.name = line;
          continue;
        }
        if (!line.trim()) {
          continue;
        }
        todo = new Todo(line, {
          position: todoList.todos.length + 1,
          todolist_id: todoList.id
        });
        if (todo != null) {
          if (todo.trashed) {
            continue;
          }
          if (todo.completed) {
            todo.position = void 0;
          } else {
            position++;
            todo.position = position;
          }
          todoList.todos.push(todo);
        }
      }
      return todoList;
    };

    TodoList.prototype.toMarkdown = function() {
      var buf, lines, todo, _i, _j, _len, _len1, _ref, _ref1;
      buf = "## " + this.name + " (#" + this.id + ")\n";
      buf += "\n";
      lines = [];
      _ref = this.todos;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        todo = _ref[_i];
        if (todo.completed === false) {
          lines.push(todo.toMarkdown());
        }
      }
      _ref1 = this.todos;
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        todo = _ref1[_j];
        if (todo.completed === true) {
          lines.push(todo.toMarkdown());
        }
      }
      lines.sort();
      buf += lines.join("");
      buf += "\n";
      return buf;
    };

    return TodoList;

  })();

  module.exports = TodoList;

}).call(this);

//# sourceMappingURL=TodoList.map
