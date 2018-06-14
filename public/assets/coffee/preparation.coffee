"use strict"

require("timeago")
require("timeago/locales/jquery.timeago.ko.js")
ReconnectingWebSocket = require("reconnectingwebsocket")
require("jquery-contextmenu/dist/jquery.ui.position.js")
require("jquery-contextmenu/dist/jquery.contextMenu.js")
require("jquery-contextmenu/dist/jquery.contextMenu.css")

$ ->
  ##---------------------
  ## Constanst & variables
  ##---------------------
  recentClick = null
  PANTS_MIN = 80
  PANTS_MAX = 120

  SELECT_RANGE = [17]
  ROOM_RANGE   = [20..34]
  REPAIR_RANGE = [6]
  BOXING_RANGE = [18]

  DEFAULT_ITEMS =
    repair:
      name: '수선'
      callback: (key, opt) ->
        bestfitPopup(6, key, opt)
    boxing:
      name: '포장'
      callback: (key, opt) ->
        bestfitPopup(18, key, opt)
  ##---------------------
  ## Socket handling
  ##---------------------
  hostname = location.hostname
  port = location.port
  protocol = location.protocol
  schema = if protocol is 'https:' then 'wss:' else 'ws:'
  url = "#{schema}//#{hostname}:#{port}/socket"
  sock = new ReconnectingWebSocket url, null, { debug: false }
  sock.onopen = (e) ->
    sock.send '/subscribe order'
    sock.send '/subscribe user'
    sock.send '/subscribe active'
    sock.send '/subscribe brain'
  sock.onmessage = (e) ->
    data   = JSON.parse(e.data)
    sender = data.sender

    ## order status
    from   = parseInt(data.from)
    to     = parseInt(data.to)

    switch sender
      when 'order'
        if from in SELECT_RANGE or to in SELECT_RANGE then reloadSelect()
        if from in ROOM_RANGE   or to in ROOM_RANGE.concat(SELECT_RANGE) then reloadRoom()
        if from in REPAIR_RANGE or to in REPAIR_RANGE then reloadRepair()
        if from in BOXING_RANGE or to in BOXING_RANGE then reloadBoxing()

        ## Refresh waiting list
        $.ajax "/repair",
          type: 'GET'
          dataType: 'json'
          success: (data, textStatus, jqXHR) ->
            male   = data.waiting.male
            female = data.waiting.female
            keys = _.union _.keys(male), _.keys(female)
            $(".table-waiting tbody span.male").empty()
            $(".table-waiting tbody span.female").empty()
            for key in keys
              $td = $(".table-waiting tbody td[data-status=\"#{key}\"]")
              if male
                m = male[key] or 0
                $male = $td.find('span.male')
                _.each _.range(m), ->
                  $male.append "<i class=\"fas fa-male male\"></i>"
              if female
                f = female[key] or 0
                $female = $td.find('span.female')
                _.each _.range(f), ->
                  $female.append "<i class=\"fas fa-female female\"></i>"
          error: (jqXHR, textStatus, errorThrown) ->
            console.log textStatus
          complete: (jqXHR, textStatus) ->
      when 'user'
        reloadSelect()
      when 'active.select'
        $("[data-order-id=#{data.order_id}]").toggleClass('active')
      when 'active.room'
        $("[data-room-no=#{data.room_no}]").toggleClass('active')
      when 'active.refresh'
        $("#room-#{data.room_no} .p-refresh").remove()
      when 'brain'
        $('#knock audio').trigger('play')
        $('#repair .repair-done').removeClass('text-success')
        ids = _.keys data.brain
        _.each ids, (order_id) ->
          $("#repair li[data-order-id=\"#{order_id}\"] .repair-done").addClass('text-success')
      else ''
  sock.onerror = (e) ->
    location.reload()
  ##---------------------
  ## Bindings
  ##---------------------
  $('#fitting-room').on 'click', '.room', (e) ->
    e.preventDefault()
    $this   = $(@)
    room_no = $this.data('room-no')
    if $this.hasClass('active')
      path = "/active/#{room_no}?key=room"
      method = 'DELETE'
    else
      path = "/active?key=room"
      method = 'POST'
      data = { room_no: room_no }
    $.ajax path,
      type: method
      data: data
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->

  $('#select').on 'click', '.select', (e) ->
    $this = $(@)
    order_id = $this.data('order-id')
    if $this.hasClass('active')
      path = "/active/#{order_id}?key=select"
      method = 'DELETE'
    else
      path = "/active?key=select"
      method = 'POST'
      data = { order_id: order_id }
    $.ajax path,
      type: method
      data: data
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->

  $('#fitting-room').on 'click', '.room .p-refresh', (e) ->
    e.preventDefault()
    e.stopPropagation()
    $this = $(@)

    room_no = $this.closest('.room').data('room-no')
    $.ajax "/active/#{room_no}?key=refresh",
      type: 'DELETE'
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->

  $('#fitting-room').on 'click', '.room .does-wear,.room .booking-date', (e) ->
    e.preventDefault()
    e.stopPropagation()
    $this = $(@)

    order_id  = $this.closest('.room').data('order-id')
    does_wear = parseInt($this.data('does-wear')) + 1
    does_wear = 0 if does_wear > 3
    updateOrder(order_id, { does_wear: does_wear })

  $('#repair').on 'click', '.btn-success', (e) ->
    e.preventDefault()
    url = $(@).attr('href')
    $.ajax url,
      type: 'PUT'
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        location.reload true
      complete: (jqXHR, textStatus) ->

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

  $('#bestfit-alert').on 'click', 'span.pants', (e) ->
    e.preventDefault()
    $this = $(@)
    size = $this.text()
    order_id = $('#bestfit-alert').data('order-id')
    $this.parent().parent().find('.pants')
      .removeClass('label-success').addClass('label-info')
    $this.removeClass('label-info').addClass('label-success')
    updateOrder order_id, { pants: size }

  $('#repair,#boxing').on 'click', 'a.pants', (e) ->
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

  $('#select').on 'click', '.js-category', (e) ->
    e.stopPropagation()

    $this    = $(@)
    category = $this.text().trim()
    user_id  = $this.data('user-id')
    updateUser user_id, { category: category }, ->
      $this.toggleClass('text-info text-muted')

  $('#select').on 'click', '.external-link', (e) ->
    e.stopPropagation()
  ##---------------------
  ## functions
  ##---------------------
  updateOrder = (order_id, params, cb) ->
    $.ajax "/api/orders/#{order_id}.json",
      type: 'PUT'
      data: params
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        location.reload true
      complete: (jqXHR, textStatus) ->
        do cb if cb

  updateUser = (user_id, params, cb) ->
    $.ajax "/api/users/#{user_id}.json",
      type: 'PUT'
      data: params
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        location.reload true
      complete: (jqXHR, textStatus) ->
        do cb if cb

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

  timeago = ->
    $(@).find("abbr.timeago").timeago()

  bestfitToggle = ->
    $(@).find('.name').click (e) ->
      e.stopPropagation()
      $this = $(@)
      order_id = $this.closest('[data-order-id]').data('order-id')
      bestfit = if $this.hasClass('bestfit') then 0 else 1
      updateOrder(order_id, { bestfit: bestfit })
      $this.toggleClass('bestfit')

  selectContextMenuItems = ->
    rooms     = $('#empty-rooms').data('empty-rooms')
    menu      = _.clone(DEFAULT_ITEMS)
    _.each rooms, (el, i) ->
      menu[el] =
        name: "탈의##{el}"
        callback: (key, opt) ->
          order_id = opt.$trigger.data('order-id')
          updateOrder(order_id, {status_id: parseInt(el) + 19})

    return menu

  registerContextMenuSelect = ->
    ## 의류준비 -> 탈의실 -> 의류준비
    $('#select .select[data-order-id]').each (i, el) ->
      $el   = $(el)
      $prev = $el.find('.previous strong')
      return true unless $prev.length

      n = parseInt($prev.text().split('/')[0].substring(1))

      menu = _.clone(DEFAULT_ITEMS)
      menu[n] =
        name: "탈의##{n}"
        callback: (key, opt) ->
          order_id = opt.$trigger.data('order-id')
          updateOrder(order_id, {status_id: n + 19})
      $.contextMenu('destroy', ".select[data-order-id='#{$el.data('order-id')}']")
      $.contextMenu
        selector: ".select[data-order-id='#{$el.data('order-id')}']"
        items: menu

    ## 치수측정 -> 의류준비
    $('#select .select[data-order-id]').each (i, el) ->
      $el   = $(el)
      $prev = $el.find('.previous strong')
      return true if $prev.length

      $.contextMenu('destroy', ".select[data-order-id='#{$el.data('order-id')}']")
      $.contextMenu
        selector: ".select[data-order-id='#{$el.data('order-id')}']"
        items: selectContextMenuItems()

  registerContextMenuRoom = ->
    $('#fitting-room .room[data-order-id]').each (i, el) ->
      $el = $(el)
      $.contextMenu
        selector: ".room[data-order-id='#{$el.data('order-id')}']"
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

  registerContextMenuRepair = ->
    $('#repair .repair[data-order-id]').each (i, el) ->
      $el = $(el)
      $.contextMenu
        selector: ".repair[data-order-id='#{$el.data('order-id')}']"
        items:
          a:
            name: '의류준비'
            callback: (key, opt) ->
              order_id = opt.$trigger.data('order-id')
              updateOrder(order_id, {status_id: 17})
          b:
            name: '포장'
            callback: (key, opt) ->
              bestfitPopup(18, key, opt)

  registerContextMenuBoxing = ->
    $('#boxing .boxing[data-order-id]').each (i, el) ->
      $el = $(el)
      $.contextMenu
        selector: ".boxing[data-order-id='#{$el.data('order-id')}']"
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

  afterLoaded = ->
    timeago.apply(@)
    bestfitToggle.apply(@)

  afterLoadedSelect = ->
    afterLoaded.apply(@)
    $(@).find('[data-toggle="popover"]').popover({ trigger: 'hover' })
    registerContextMenuSelect()

  afterLoadedRoom = ->
    afterLoaded.apply(@)
    registerContextMenuRoom()

  afterLoadedRepair = ->
    afterLoaded.apply(@)
    registerContextMenuRepair()

  afterLoadedBoxing = ->
    afterLoaded.apply(@)
    registerContextMenuBoxing()

  reloadSelect = ->
    $('#select').load '/region/selects', afterLoadedSelect

  reloadRoom = ->
    $('#fitting-room').load '/region/rooms', afterLoadedRoom

  reloadRepair = ->
    $('#repair').load '/region/status/repair', afterLoadedRepair

  reloadBoxing = ->
    $('#boxing').load '/region/status/boxing', afterLoadedBoxing
  ##---------------------
  ## main
  ##---------------------
  reloadRoom()
  reloadSelect()
  reloadRepair()
  reloadBoxing()
