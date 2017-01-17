express = require 'express'
cookieParser = require('cookie-parser')
bodyParser = require("body-parser")

Wit = require('node-wit').Wit
interactive = require('node-wit').interactive
accessToken = process.argv[2]
witclient = new Wit({accessToken: "GICI3TOXA5IM7ZIQSM6GIGXLR3UIKD7X"})
reminder_list = []
convo_list = []
robot_inst = null
reminder_ct = 0

#### Basic application initialization
# Create app instance.
app = express()

# Define Port & Environment
app.port = process.env.PORT or process.env.VMC_APP_PORT or 8001
env = process.env.NODE_ENV or "development"

# Config module exports has `setEnvironment` function that sets app settings depending on environment.
#config = require "./config"
#config.setEnvironment env

app.use cookieParser()
# [Body parser middleware](http://www.senchalabs.org/connect/middleware-bodyParser.html) parses JSON or XML bodies into `req.body` object
app.use bodyParser()

# simple session authorization
checkAuth = (req, res, next) ->
  unless req.session.authorized
    res.statusCode = 401
    res.render '401', 401
  else
    next()

# set reminder api
# body parameters : room, reminder_str, time
app.post '/set_reminder', (req, res, next) ->
  if robot_inst
    t = Date.parse(req.body.time) - Date.parse(new Date())
    job = setTimeout run_reminder.bind(this, req.body.reminder_str, robot_inst, {room: req.body.room}, reminder_ct), t
    reminder_list.push {job:job, reminder_str: req.body.reminder_str, reminder_date: Date.parse(req.body.time), envelope: {room: req.body.room}}
    reminder_ct = reminder_ct + 1
    res.status(200).send {result:"Reminder is set successfully"}
  else
    res.status(500).send {result:"Robot is not initialized!"}

app.post '/set_directreminder', (req, res, next) ->
  if robot_inst
    t = Date.parse(req.body.time) - Date.parse(new Date())
    job = setTimeout run_reminder.bind(this, req.body.reminder_str, robot_inst, {room: req.body.room}, reminder_ct), t
    reminder_list.push {job:job, reminder_str: req.body.reminder_str, reminder_date: Date.parse(req.body.time), envelope: {room: robot.adapter.getDirectMessageRoomId req.body.room}}
    reminder_ct = reminder_ct + 1
    res.status(200).send {result:"Reminder is set successfully"}
  else
    res.status(500).send {result:"Robot is not initialized!"}

app.post '/remove_reminder', (req, res, next) ->
  if robot_inst
    reminder_idx = -1
    for i in [0..reminder_list.length-1]
      if reminder_list[i].id == req.body.idx
        reminder_idx = i
    if reminder_idx > -1
      reminder_list.slice reminder_idx, 1
      res.status(200).send {result:"Reminder is removed successfully"}
    else
      res.status(401).send {result:"Reminder is not found!"}
  else
    res.status(500).send {result:"Robot is not initialized!"}

app.listen app.port, () ->
  return console.log("Listening on " + app.port + "\nPress CTRL-C to stop server.")


run_reminder = (reminder, robot, envelope, idx) ->
  reminder_idx = -1
  for i in [0..reminder_list.length-1]
    if reminder_list[i].id == idx
      reminder_idx = i
  robot.send envelope, reminder
  convo_list.push reminder_list[reminder_idx]
  reminder_list.slice reminder_idx, 1

module.exports = (robot) ->

  robot_inst = robot
  # robot.hear /badger/i, (res) ->
  #   res.send "Badgers? BADGERS? WE DON'T NEED NO STINKIN BADGERS"
  #
  robot.respond /show your reminders/i, (res) ->
    err = new Error()
    console.log err.stack
    if reminder_list.length
      robot.send res.envelope, "Reminder list : (REMINDER_STRING : REMINDER_TIME)"
      for item in reminder_list
        robot.send item.envelope, item.reminder_str+"\t:\t"+item.reminder_date
    else
      res.reply "There is no set Reminder"

  robot.respond /(.*)every(.*)/i, (res) ->
    console.log res
    if convo_list.length
      res.reply "this is in conversation with bot."
    else
      ret_promise = witclient.message res.message.text, {}
      ret_promise.then (data) ->
        if data.entities.datetime[0].value
          reminder_time = data.entities.datetime[0].value
        else
          reminder_time = data.entities.datetime[0].from.value
        #console.log res.envelope
        t = Date.parse(reminder_time) - Date.parse(new Date())
        reminder_str = data.entities.reminder[0].value
        job = setTimeout run_reminder.bind(this, data.entities.reminder[0].value, robot, res.envelope, reminder_ct), t
        reminder_list.push {id:reminder_ct, job:job, reminder_str: data.entities.reminder[0].value, reminder_date: reminder_time, envelope: res.envelope, interval:t}
        reminder_ct = reminder_ct + 1

  robot.respond /(.*)/i, (res) ->
    if convo_list.length
      ret_promise = witclient.message res.message.text, {}
      ret_promise.then (data) ->
        if data.entities.yes_reply.length
          for i in [0..reminder_list.length-1]
            if reminder_list[i].id == convo_list[0].id
              reminder_list.slice i, 1
          convo_list.slice 0, 1
        else if data.entities.no_reply.length
          convo_list.slice 0, 1
    else
      ret_promise = witclient.message res.message.text, {}
      ret_promise.then (data) ->
        if data.entities.datetime.length
          reminder_time = data.entities.datetime[0].value
        else
          reminder_time = data.entities.datetime[0].from.value
        #console.log res.envelope
        t = Date.parse(reminder_time) - Date.parse(new Date())
        reminder_str = data.entities.reminder[0].value
        job = setTimeout run_reminder.bind(this, data.entities.reminder[0].value, robot, res.envelope, reminder_ct), t
        reminder_list.push {id:reminder_ct, job:job, reminder_str: data.entities.reminder[0].value, reminder_date: reminder_time, envelope: res.envelope}
        reminder_ct = reminder_ct + 1
        #console.log res
        #res.reply "#{reminder_time} : #{reminder_str}"

    #date = res.match[2]
    #task = res.match[1]
    #res.reply "Oh! I will remember and inform you at #{date} about you need to do #{task}"
  robot.hear /^test$/i, (res) ->
    res.send "Test? TESTING? WE DON'T NEED NO TEST, EVERYTHING WORKS!"

# Description:
#   Example scripts for you to examine and try out.
#
# Notes:
#   They are commented out by default, because most of them are pretty silly and
#   wouldn't be useful and amusing enough for day to day huboting.
#   Uncomment the ones you want to try and experiment with.
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md

#module.exports = (robot) ->

#  robot.hear /^test$/i, (res) ->
#    res.send "Test? TESTING? WE DON'T NEED NO TEST, EVERYTHING WORKS!"
#
#
# robot.respond /open the (.*) doors/i, (res) ->
#   doorType = res.match[1]
#   if doorType is "pod bay"
#     res.reply "I'm afraid I can't let you do that."
#   else
#     res.reply "Opening #{doorType} doors"
#
#
# robot.hear /I like pie/i, (res) ->
#   res.emote "makes a freshly baked pie"
#
#
# robot.respond /lulz/i, (res) ->
#   res.send res.random ['lol', 'rofl', 'lmao']
#
#
# robot.topic (res) ->
#   res.send "#{res.message.text}? That's a Paddlin'"
#
#
# robot.enter (res) ->
#   res.send res.random ['Hi', 'Target Acquired', 'Firing', 'Hello friend.', 'Gotcha', 'I see you']
#
#
# robot.leave (res) ->
#   res.send res.random ['Are you still there?', 'Target lost', 'Searching']
#
#
# answer = process.env.HUBOT_ANSWER_TO_THE_ULTIMATE_QUESTION_OF_LIFE_THE_UNIVERSE_AND_EVERYTHING
# robot.respond /what is the answer to the ultimate question of life/, (res) ->
#   unless answer?
#     res.send "Missing HUBOT_ANSWER_TO_THE_ULTIMATE_QUESTION_OF_LIFE_THE_UNIVERSE_AND_EVERYTHING in environment: please set and try again"
#     return
#   res.send "#{answer}, but what is the question?"
#
#
# robot.respond /you are a little slow/, (res) ->
#   setTimeout () ->
#     res.send "Who you calling 'slow'?"
#   , 60 * 1000
#
#
# annoyIntervalId = null
#
# robot.respond /annoy me/, (res) ->
#   if annoyIntervalId
#     res.send "AAAAAAAAAAAEEEEEEEEEEEEEEEEEEEEEEEEIIIIIIIIHHHHHHHHHH"
#     return
#   res.send "Hey, want to hear the most annoying sound in the world?"
#   annoyIntervalId = setInterval () ->
#     res.send "AAAAAAAAAAAEEEEEEEEEEEEEEEEEEEEEEEEIIIIIIIIHHHHHHHHHH"
#   , 1000
#
# robot.respond /unannoy me/, (res) ->
#   if annoyIntervalId
#     res.send "GUYS, GUYS, GUYS!"
#     clearInterval(annoyIntervalId)
#     annoyIntervalId = null
#   else
#     res.send "Not annoying you right now, am I?"
#
#
# robot.router.post '/hubot/chatsecrets/:room', (req, res) ->
#   room   = req.params.room
#   data   = JSON.parse req.body.payload
#   secret = data.secret
#   robot.messageRoom room, "I have a secret: #{secret}"
#   res.send 'OK'
#
#
# robot.error (err, res) ->
#   robot.logger.error "DOES NOT COMPUTE"
#   if res?
#     res.reply "DOES NOT COMPUTE"
#
#
# robot.respond /have a soda/i, (res) ->
#   # Get number of sodas had (coerced to a number).
#   sodasHad = robot.brain.get('totalSodas') * 1 or 0
#   if sodasHad > 4
#     res.reply "I'm too fizzy.."
#   else
#     res.reply 'Sure!'
#     robot.brain.set 'totalSodas', sodasHad+1
#
#
# robot.respond /sleep it off/i, (res) ->
#   robot.brain.set 'totalSodas', 0
#   res.reply 'zzzzz'
