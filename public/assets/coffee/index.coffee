"use strict"
## Status map
statusMap =
  6:  'repair'
  13: 'visit'
  16: 'measure'
  17: 'select'
  18: 'boxing'
  44: 'boxed'
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
  29: 'undress'
  30: 'undress'

## Event
class EventStream
  constructor: ->
    _.extend @, Backbone.Events
    hostname = location.hostname
    port = location.port
    protocol = location.protocol
    schema = if protocol is 'https:' then 'wss:' else 'ws:'
    url = "#{schema}//#{hostname}:#{port}/socket"
    @count = 0
    @socket = new ReconnectingWebSocket url, null, { debug: false }
    @socket.onopen = (e) =>
      @socket.send '/subscribe order'
    @socket.onmessage = (e) =>
      new NotificationRow
        model: new NotificationModel { stream: @, count: @count++ }
      @trigger 'receiveMessage', e
    @socket.onerror = (e) =>
      @trigger 'error', e
    @socket.onclose = (e) =>
      @trigger 'close', e

## Model
class NotificationModel extends Backbone.Model
  initialize: (opts) ->
    @stream = opts.stream
    @stream.on 'receiveMessage', (e) =>
      data = JSON.parse(e.data)
      return if @get 'order_id'
      @set
        count: opts.count
        order_id: data.order.id
        create_date: data.order.create_date.replace(' ', 'T') + 'Z'
        booking_date: data.order.booking.date.substr(11, 5)
        from: data.from
        to: data.to
        extra: data.extra
        username: data.order.user.name
        desc: switch statusMap[data.to]
          when 'visit'   then '대기중입니다'
          when 'select'  then '의류 준비를 기다려주세요'
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
    from = @model.get('from')
    to   = @model.get('to')
    status_id = if to > 19 and to < 40 then 20 else to
    userlabel = $("#order-#{@model.get('order_id')}").get(0)
    unless _.contains(_.keys(statusMap), '' + status_id)
      $(userlabel).remove()
      return @

    return @ unless @model.get 'desc'

    ## 임시로 skip, 22:00 는 온라인 대여자
    return @ if @model.get('booking_date') is '22:00'

    ## 의류준비 - 탈의의 상태가 반복되는 사용자는 알람을 끈다
    _from = if from > 19 and from < 40 then 20 else parseInt(from)
    _to   = if to > 19 and to < 40 then 20 else parseInt(to)
    found = _.findWhere [{ from: 17, to: 20 }, { from: 20, to: 17 }], { from: _from, to: _to }

    if found and @model.get('extra').nth > 1
      console.log '2번이상 탈의'
      return @
    else if found and @model.get('extra').nth is 1 and _from is 20
      console.log '탈의 -> 의류준비'
      return @
    else
      $('#event audio').trigger('play')

    @$el.append(@template(@model.attributes)).prependTo('#event ul')
    setTimeout =>
      @remove()
      if @model.get('count') > 30 and $('#event ul li').size() is 0
        location.reload()
    , 1000 * 60    # 60 secs
    unless userlabel
      compiled = _.template '''
        <p class="user" id="order-<%= order_id %>">
          <span class="label label-info">
            <%= username %>
            <span class="date"><%= booking_date %></span>
          </span>
          <abbr title="<%= create_date %>"><%= create_date %></abbr>
        </p>
      '''
      userlabel = compiled
        order_id: @model.get('order_id')
        username: @model.get('username')
        create_date: @model.get('create_date')
        booking_date: @model.get('booking_date')

    $userlabel = $(userlabel)
    $userlabel.find('span.badge').remove()
    if statusMap[to] is 'undress'
      $label = $userlabel.find('span.label')
      $label.prepend("<span class=\"badge\">#{to - 19}</span>")

    guessBooking($userlabel).appendTo($("#status-#{status_id}"))
    return @

## functions
guessBooking = ($el) ->
  now = new Date().getTime()
  createTime = $el.find('abbr').text()
  if distanceMinutes(now - new Date(createTime).getTime()) < 30
    # 예약안한 사람
    $el.find('span.label').removeClass().addClass('label label-default')
  else
    # 예약한 사람
    $el.find('span.label').removeClass().addClass('label label-info')
  return $el

distanceHours = (millis) ->
  seconds = Math.abs(millis) / 1000;
  minutes = seconds / 60
  hours = minutes / 60
  days = hours / 24
  years = days / 365
  return hours

distanceMinutes = (millis) ->
  seconds = Math.abs(millis) / 1000;
  minutes = seconds / 60
  hours = minutes / 60
  days = hours / 24
  years = days / 365
  return minutes

## main
$ ->
  $('.user').each (i, el) ->
    guessBooking($(el))
  stream = new EventStream()
  stream.on 'error', (e) ->
    location.reload()

  $('.datepicker').datepicker
    language: 'kr'
    todayHighlight: true
    format: 'yyyy-mm-dd'
    autoclose: true
  .on 'changeDate', (e) ->
    ymd = $(@).datepicker('getFormattedDate')
    $.ajax "/brain",
      type: 'PUT'
      data: { k: 'expiration', v: ymd }
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->

