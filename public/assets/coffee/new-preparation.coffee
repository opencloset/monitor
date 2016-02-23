"use strict"

class EventStream
  constructor: ->
    _.extend @, Backbone.Events
    hostname = location.hostname
    port     = location.port
    protocol = location.protocol
    schema   = if protocol is 'https:' then 'wss:' else 'ws:'
    url      = "#{schema}//#{hostname}:#{port}/socket"
    @socket = new ReconnectingWebSocket url, null, { debug: false }
    @socket.onopen = (e) =>
      @socket.send '/subscribe order'
      @socket.send '/subscribe user'
      @socket.send '/subscribe active'
      @socket.send '/subscribe brain'
    @socket.onmessage = (e) =>
      data   = JSON.parse(e.data)
      sender = data.sender
      switch sender
        when 'order'
          ''
        when 'user'
          ''
        when 'active.room'
          ''
        when 'active.select'
          new ActiveSelectView({ model: new ActiveSelectModel({ stream: @ }) })
          @trigger 'receiveMessage', data
        when 'brain'
          ''
        else ''
    @socket.onerror = (e) =>
      @trigger 'error', e
    @socket.onclose = (e) =>
      @trigger 'close', e

class ActiveSelectModel extends Backbone.Model
  initialize: (opts) ->
    @stream = opts.stream
    @stream.on 'receiveMessage', (data) =>
      @set { order_id: data.order_id }

class ActiveSelectView extends Backbone.View
  initialize: ->
    @listenTo(@model, 'change', @render)
  render: =>
    order_id = @model.get('order_id')
    $("[data-order-id=#{order_id}]").toggleClass('active')
    return @

## main
$ ->
  stream = new EventStream()
  stream.on 'error', (e) ->
    location.reload()
