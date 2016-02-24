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
      range  = [20..30]

      range.unshift 17
      range.unshift 18
      range.unshift 6

      console.log sender

      switch sender
        when 'order'
          new DashboardView({ model: new DashboardModel({ stream: @ }) })
          @trigger 'receiveMessage', data
          if parseInt(data.from) in range or parseInt(data.to) in range
            new OrderView({ model: new OrderModel({ stream: @ }) })
            @trigger 'receiveMessage', data
        when 'user'
          new UserView({ model: new UserModel({ stream: @ }) })
          @trigger 'receiveMessage', data
        when 'active.room', 'active.select'
          new ActiveView({ model: new ActiveModel({ stream: @ }) })
          @trigger 'receiveMessage', data
        when 'brain'
          new BrainView({ model: new BrainModel({ stream: @ }) })
          @trigger 'receiveMessage', data
        else ''
    @socket.onerror = (e) =>
      @trigger 'error', e
    @socket.onclose = (e) =>
      @trigger 'close', e

##
## Model
##

class ActiveModel extends Backbone.Model
  initialize: (opts) ->
    @stream = opts.stream
    @stream.on 'receiveMessage', (data) =>
      @set { order_id: data.order_id }

class BrainModel extends Backbone.Model
  initialize: (opts) ->
    @stream = opts.stream
    @stream.on 'receiveMessage', (data) =>
      @set { brain: data.brain }

class DashboardModel extends Backbone.Model
  initialize: (opts) ->
    @stream = opts.stream
    @stream.on 'receiveMessage', (data) =>
      $.ajax "/repair",
        type: 'GET'
        dataType: 'json'
        success: (data, textStatus, jqXHR) =>
          @set { male: data.waiting.male, female: data.waiting.female }
        error: (jqXHR, textStatus, errorThrown) ->
          console.log textStatus
        complete: (jqXHR, textStatus) ->

class OrderModel extends Backbone.Model
  initialize: (opts) ->
    @stream = opts.stream
    @stream.on 'receiveMessage', (data) =>
      @set { order_id: data.order_id, from: data.from, to: data.to, extra: data.extra }

class UserModel extends Backbone.Model
  initialize: (opts) ->
    @stream = opts.stream
    @stream.on 'receiveMessage', (data) =>
      @set { user_id: data.user_id }

##
## View
##

class ActiveView extends Backbone.View
  initialize: ->
    @listenTo(@model, 'change', @render)
  render: =>
    order_id = @model.get('order_id')
    $("[data-order-id=#{order_id}]").toggleClass('active')
    return @

class BrainView extends Backbone.View
  initialize: ->
    @listenTo(@model, 'change', @render)
  render: =>
    brain = @model.get('brain')
    $('#knock audio').trigger('play')
    $('#repair .repair-done').removeClass('text-success')
    ids = _.keys brain
    _.each ids, (order_id) ->
      $("#repair li[data-order-id=\"#{order_id}\"] .repair-done").addClass('text-success')
    return @

class DashboardView extends Backbone.View
  initialize: ->
    @listenTo(@model, 'change', @render)
  render: =>
    male   = @model.get 'male'
    female = @model.get 'female'
    keys   = _.union _.keys(male), _.keys(female)
    $(".table-waiting tbody span.male").empty()
    $(".table-waiting tbody span.female").empty()
    for key in keys
      $td = $(".table-waiting tbody td[data-status=\"#{key}\"]")
      if male
        m = male[key] or 0
        $male = $td.find('span.male')
        _.each _.range(m), ->
          $male.append "<i class=\"fa fa-male male\"></i>"
      if female
        f = female[key] or 0
        $female = $td.find('span.female')
        _.each _.range(f), ->
          $female.append "<i class=\"fa fa-female female\"></i>"
    return @

class OrderView extends Backbone.View
  initialize: ->
    @listenTo(@model, 'change', @render)
  render: =>
    order_id = @model.get 'order_id'
    from     = @model.get 'from'
    to       = @model.get 'to'
    extra    = @model.get 'extra'

    if from is to
      if extra.bestfit
        $("[data-order-id='#{order_id}']").find('.name').addClass('bestfit')
      else
        $("[data-order-id='#{order_id}']").find('.name').removeClass('bestfit')
    else
      location.reload()
    return @

class UserView extends Backbone.View
  initialize: ->
    @listenTo(@model, 'change', @render)
  render: =>
    location.reload()
    # reload 대신에 pants 길이를 바꿔줘야?
    return @

##
## main
##

$ ->
  $("abbr.timeago").timeago()

  stream = new EventStream()
  stream.on 'error', (e) ->
    location.reload()

  $('.room').click (e) ->
    e.preventDefault()
    $this = $(@)
    order_id = $this.parent().data('order-id')
    if $this.parent().hasClass('active')
      path = "/room/#{order_id}"
      method = 'DELETE'
    else
      path = "/room"
      method = 'POST'
      data = { order_id: order_id }
    $.ajax path,
      type: method
      data: data
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->

  $('.select').click (e) ->
    $this = $(@)
    order_id = $this.data('order-id')
    if $this.hasClass('active')
      path = "/select/#{order_id}"
      method = 'DELETE'
    else
      path = "/select"
      method = 'POST'
      data = { order_id: order_id }
    $.ajax path,
      type: method
      data: data
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->

  items =
    repair:
      name: '수선'
      callback: (key, opt) ->
        bestfitPopup(6, key, opt)
    boxing:
      name: '포장'
      callback: (key, opt) ->
        bestfitPopup(18, key, opt)
  _.each [1..11], (el, i) ->
    items[el] =
      name: "탈의##{el}"
      callback: (key, opt) ->
        order_id = opt.$trigger.data('order-id')
        updateOrder(order_id, {status_id: parseInt(el) + 19})

  $.contextMenu
    selector: '.select[data-order-id]'
    items: items

  $.contextMenu
    selector: '[data-order-id]:not(.select)'
    items:
      a:
        name: '의류준비'
        callback: (key, opt) ->
          order_id = opt.$trigger.data('order-id')
          updateOrder(order_id, {status_id: 17})
      b:
        name: '수선'
        callback: (key, opt) ->
          bestfitPopup(6, key, opt)
      c:
        name: '포장'
        callback: (key, opt) ->
          bestfitPopup(18, key, opt)

  $('#bestfit-alert').on 'click', '.btn-success', (e) ->
    $('#bestfit-alert').data('bestfit', 1).addClass('hidden')
      .trigger('closed.bs.alert')

  $('#bestfit-alert').on 'click', '.btn-warning', (e) ->
    $('#bestfit-alert').data('bestfit', 0).addClass('hidden')
      .trigger('closed.bs.alert')

  $('#bestfit-alert').on 'click', 'button.close', (e) ->
    $('#bestfit-alert')
      .removeData('order-id')
      .removeData('status-id')
      .removeData('bestfit')
      .addClass('hidden')
      .trigger('closed.bs.alert')

  $('#bestfit-alert').on 'closed.bs.alert', ->
    order_id  = $(@).data('order-id')
    status_id = $(@).data('status-id')
    bestfit   = $(@).data('bestfit')
    return unless bestfit?
    updateOrder(order_id, {status_id: status_id, bestfit: bestfit})

  updateOrder = (order_id, params, cb) ->
    $.ajax "/api/orders/#{order_id}.json",
      type: 'PUT'
      data: params
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        location.reload true
      complete: (jqXHR, textStatus) ->
        do cb if cb

  $('#repair .btn-success').click (e) ->
    e.preventDefault()
    url = $(@).attr('href')
    $.ajax url,
      type: 'PUT'
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        location.reload true
      complete: (jqXHR, textStatus) ->

  $('.name').click (e) ->
    e.stopPropagation()
    $this = $(@)
    order_id = $this.closest('[data-order-id]').data('order-id')
    bestfit = if $this.hasClass('bestfit') then 0 else 1
    updateOrder(order_id, { bestfit: bestfit })
    $this.toggleClass('bestfit')

  bestfitPopup = (status_id, key, opt) ->
    order_id = opt.$trigger.data('order-id')
    $bestfit = $('#bestfit-alert')
    $bestfit.data('order-id', order_id)
    $bestfit.data('status-id', status_id)
    $bestfit.removeClass('hidden')

    $bestfit.find('.btn').removeClass('bestfit')
    name = opt.$trigger.find('.name').text()
    $bestfit.find('h4 small').text(name)
    isBestfit = opt.$trigger.has('.bestfit').length
    if isBestfit
      $bestfit.find('.btn-success').addClass('bestfit')
    else
      $bestfit.find('.btn-warning').addClass('bestfit')

  PANTS_MIN = 90
  PANTS_MAX = 120
  recentClick = null
  $('a.pants').on 'click', (e) ->
    e.preventDefault()
    $this = $(@)
    $samp = $this.parent().find('samp')
    current = $samp.text() or 0
    rule = $(@).data('rule')
    pad = if rule is 'up' then 1 else -1
    current = parseInt(current) + pad
    if current < PANTS_MIN then current = PANTS_MIN
    if current > PANTS_MAX then current = PANTS_MAX
    $samp.html(current)

    recentClick = Date.now()
    setTimeout ->
      now = Date.now()
      return unless now - recentClick >= 2000
      order_id = $this.closest('[data-order-id]').data('order-id')
      updateOrder order_id, { pants: current }, ->
        $samp.addClass 'text-success'
        setTimeout ->
          $samp.removeClass 'text-success'
        , 1000
    , 2000

  $('#bestfit-alert').on 'click', 'span.pants', (e) ->
    e.preventDefault()
    $this = $(@)
    size = $this.text()
    order_id = $('#bestfit-alert').data('order-id')
    $this.parent().parent().find('.pants')
      .removeClass('label-success').addClass('label-info')
    $this.removeClass('label-info').addClass('label-success')
    updateOrder order_id, { pants: size }

  $('[data-toggle="tooltip"]').tooltip()
