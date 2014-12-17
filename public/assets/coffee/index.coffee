## Event
class EventStream
  constructor: ->
    console.log 'EventStream::constructor'
    _.extend @, Backbone.Events
    hostname = location.hostname
    port = location.port
    protocol = location.protocol
    schema = if protocol is 'https:' then 'wss:' else 'ws:'
    url = "#{schema}//#{hostname}:#{port}/socket"
    @socket = new ReconnectingWebSocket url, null, { debug: false }
    @socket.onmessage = (e) =>
      console.log 'EventStream::socket::onmessage'
      new NotificationRow
        model: new NotificationModel { stream: @ }
      @trigger 'receiveMessage', e
    @socket.onerror = (e) =>
      @trigger 'receiveError', e

## Model
class NotificationModel extends Backbone.Model
  initialize: (opts) ->
    console.log 'NotificationModel::initialize'
    @stream = opts.stream
    @stream.on 'receiveMessage', (e) =>
      console.log 'NotificationModel::stream::receiveMessage'
      return if @has 'html'
      @set 'html', e.data
      setTimeout =>
        @unset 'html'
      , 1000 * 15

## View
class NotificationRow extends Backbone.View
  initialize: ->
    console.log 'NotificationView::initialize'
    @listenTo(@model, 'change', @render)
  tagName: 'li'
  className: 'list-group-item'
  render: =>
    console.log 'NotificationView::render'
    html = @model.get('html')
    if html
      $('#event audio').trigger('play')
      @$el.append(html).appendTo('#event ul')
    else
      @remove()

## main
$ ->
  $("abbr.timeago").timeago()
  stream = new EventStream
