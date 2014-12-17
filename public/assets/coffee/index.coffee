## Status map
statusMap =
  6:  'repair'
  13: 'visit'
  16: 'measure'
  17: 'select'
  18: 'boxing'
  19: 'payment'
  20: 'undress'
  21: 'undress'
  22: 'undress'
  23: 'undress'
  24: 'undress'
  25: 'undress'
  26: 'undress'
  27: 'undress'
  28: 'undress'


## Event
class EventStream
  constructor: ->
    _.extend @, Backbone.Events
    hostname = location.hostname
    port = location.port
    protocol = location.protocol
    schema = if protocol is 'https:' then 'wss:' else 'ws:'
    url = "#{schema}//#{hostname}:#{port}/socket"
    @socket = new ReconnectingWebSocket url, null, { debug: false }
    @socket.onmessage = (e) =>
      new NotificationRow
        model: new NotificationModel { stream: @ }
      @trigger 'receiveMessage', e
    @socket.onerror = (e) =>
      @trigger 'receiveError', e

## Model
class NotificationModel extends Backbone.Model
  initialize: (opts) ->
    @stream = opts.stream
    @stream.on 'receiveMessage', (e) =>
      data = JSON.parse(e.data)
      return if @get 'order_id'
      @set
        order_id: data.order.id
        from: data.from
        to: data.to
        username: data.order.user.name
        desc: switch statusMap[data.to]
          when 'visit'   then '대기중입니다'
          when 'select'  then '의류를 준비하고 있습니다'
          when 'repair'  then '의류를 수선 중 입니다'
          when 'boxing'  then '의류를 포장 중 입니다'
          when 'measure' then '신체 치수 측정 장소로 와주세요'
          when 'undress' then "#{data.to - 19}번 탈의실로 입장해 주세요"
          when 'payment' then '결제 장소로 와주세요'
          else ''

## View
class NotificationRow extends Backbone.View
  initialize: ->
    @listenTo(@model, 'change', @render)
  tagName: 'li'
  className: 'list-group-item'
  template: _.template '''
  <h1>
    <span><%= username %></span>님
    <small><%= desc %></small>
  </h1>
  '''
  render: =>
    $('#event audio').trigger('play')
    to = @model.get('to')
    status_id = if to > 19 and to < 29 then 20 else to
    userlabel = $("#order-#{@model.get('order_id')}").get(0)
    unless _.contains(_.keys(statusMap), '' + status_id)
      $(userlabel).remove()
      return @

    return @ unless @model.get 'desc'

    @$el.append(@template(@model.attributes)).appendTo('#event ul')
    setTimeout =>
      @remove()
    , 1000 * 15
    unless userlabel
      compiled = _.template '''
        <p class="user" id="order-<%= order_id %>">
          <span class="label label-info"><%= username %></span>
        </p>
      '''
      userlabel = compiled
        order_id: @model.get('order_id')
        username: @model.get('username')
    $(userlabel).appendTo($("#status-#{status_id}"))
    return @

## main
$ ->
  stream = new EventStream
