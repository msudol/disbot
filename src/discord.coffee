try
    {Robot, Adapter, TextMessage} = require "hubot"
catch
    prequire = require "parent-require"
    {Robot, Adapter, TextMessage} = prequire "hubot"

Discord = require "discord.js"

class DiscordAdapter extends Adapter
    constructor: (robot) ->
        super robot
        @rooms = {}

    messageChannel: (channelId, message, callback) ->
        robot = @robot
        sendMessage = (channel, message, callback) ->
            callback ?= (err, success) -> {}

            channel.sendMessage(message)
                .then (msg) ->
                    robot.logger.debug "SUCCESS! Send message to channel #{channel.id}"
                    callback null, true
                .catch (err) ->
                    robot.logger.error "Error while trying to send message #{message}"
                    robot.logger.error err
                    callback err, false

        @robot.logger.debug "Disbot: Try to send message: \"#{message}\" to channel: #{channelId}"

        if @rooms[channelId]? # room is already known and cached
            sendMessage @rooms[channelId], message, callback
        else # unknown room, try to find it
            channels = @discord.channels.filter (channel) -> channel.id == channelId

            if channels.first()?
                sendMessage channels.first(), message, callback
            else
                @robot.logger.error "Unknown channel id: #{channelId}"
                callback {message: "Unknown channel id: #{channelId}"}, false

    send: (envelope, messages...) ->
        for message in messages
            @messageChannel envelope.room, message

    reply: (envelope, messages...) ->
        for message in messages
            @messageChannel envelope.room, "<@#{envelope.user.id}> #{message}"

    run: ->
        @token = process.env.DISBOT_TOKEN

        if not @token?
            @robot.logger.error "Disbot Error: No token specified, please set an environment variable named DISBOT_TOKEN"
            return

        @discord = new Discord.Client autoReconnect: true

        @discord.on "ready", @.onready
        @discord.on "message", @.onmessage
        @discord.on "disconnected", @.ondisconnected

        @discord.login @token

    onready: =>
        @robot.logger.info "Disbot: Logged in as User: #{@discord.user.username}##{@discord.user.discriminator}"
        @robot.name = @discord.user.username.toLowerCase()

        @emit "connected"

    onmessage: (message) =>
        return if message.author.id == @discord.user.id # skip messages from the bot itself

        user = @robot.brain.userForId message.author.id

        user.name = message.author.username
        user.discriminator = message.author.discriminator
        user.room = message.channel.id

        @rooms[user.room] ?= message.channel

        text = message.content

        @robot.logger.debug "Disbot: Message (ID: #{message.id} from: #{user.name}##{user.discriminator}): #{text}"
        @robot.receive new TextMessage(user, text, message.id)

    ondisconnected: =>
        @robot.logger.info "Disbot: Bot lost connection to the server, will auto reconnect soon..."

exports.use = (robot) ->
    new DiscordAdapter robot
