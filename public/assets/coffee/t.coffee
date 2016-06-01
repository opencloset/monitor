"use strict"
$ ->
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

    selectRange = [17]
    roomRange   = [20..30]
    repairRange = [6]
    boxingRange = [18]

    switch sender
      when 'order'
        if from in selectRange or to in selectRange then reloadSelect()
        if from in roomRange   or to in roomRange   then reloadRoom()
        if from in repairRange or to in repairRange then reloadRepair()
        if from in boxingRange or to in boxingRange then reloadBoxing()

        ## Refresh waiting list
        ## 이것도 복잡해지면 `$.load` 로 대체해야..
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
                  $male.append "<i class=\"fa fa-male male\"></i>"
              if female
                f = female[key] or 0
                $female = $td.find('span.female')
                _.each _.range(f), ->
                  $female.append "<i class=\"fa fa-female female\"></i>"
          error: (jqXHR, textStatus, errorThrown) ->
            console.log textStatus
          complete: (jqXHR, textStatus) ->
      when 'user'
        reloadSelect()
      when 'active.room', 'active.select'
        $("[data-order-id=#{data.order_id}]").toggleClass('active')
      when 'active.refresh'
        $("#room-#{data.order_id} .p-refresh").remove()
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
  ## variables
  ##---------------------
  items =
    repair:
      name: '수선'
      callback: (key, opt) ->
        bestfitPopup(6, key, opt)
    boxing:
      name: '포장'
      callback: (key, opt) ->
        bestfitPopup(18, key, opt)

  PANTS_MIN = 80
  PANTS_MAX = 120
  recentClick = null
  ##---------------------
  ## Bindings
  ##---------------------
  $('#fitting-room').on 'click', '.room', (e) ->
    e.preventDefault()
    $this = $(@)
    order_id = $this.data('order-id')
    if $this.hasClass('active')
      path = "/active/#{order_id}?key=room"
      method = 'DELETE'
    else
      path = "/active?key=room"
      method = 'POST'
      data = { order_id: order_id }
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

  $('#fitting-room').on 'click', '.room .empty', (e) ->
    e.preventDefault()
    $this = $(@)
    $p = $this.find('.p-refresh')
    return unless $p.length

    room_no = $this.find('h3').text().trim().substring(1)
    $.ajax "/active/#{room_no}?key=refresh",
      type: 'DELETE'
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->

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


  selectContextMenuItems = (rooms) ->
    $('#fitting-room .room[data-order-id]').each (i, el) ->
      n = parseInt($(el).find('h3').text().trim().substring(1))
      rooms.push(n)

    menu      = _.clone(items)
    available = _.difference([1..11], rooms)
    _.each available, (el, i) ->
      menu[el] =
        name: "탈의##{el}"
        callback: (key, opt) ->
          order_id = opt.$trigger.data('order-id')
          updateOrder(order_id, {status_id: parseInt(el) + 19})

    return menu


  afterLoaded = ->
    timeago.apply(@)
    bestfitToggle.apply(@)


  afterLoadedSelect = ->
    afterLoaded.apply(@)

    $this = $(@)
    $this.find('[data-toggle="tooltip"]').tooltip()

    reservedRoom = []
    $this.find('.select[data-order-id]').each (i, el) ->
      $el   = $(el)
      $prev = $el.find('.previous strong')
      return true unless $prev.length

      n = parseInt($prev.text().split('/')[0].substring(1))
      reservedRoom.push(n)

      menu = _.clone(items)
      menu[n] =
        name: "탈의##{n}"
        callback: (key, opt) ->
          order_id = opt.$trigger.data('order-id')
          updateOrder(order_id, {status_id: n + 19})
      $.contextMenu
        selector: ".select[data-order-id='#{$el.data('order-id')}']"
        items: menu

    ## 앞서 한바퀴 돌리면서 reservedRoom 을 채우고 이를 다시 돌면서 활용
    $this.find('.select[data-order-id]').each (i, el) ->
      $el   = $(el)
      $prev = $el.find('.previous strong')
      return true if $prev.length

      $.contextMenu
        selector: ".select[data-order-id='#{$el.data('order-id')}']"
        items: selectContextMenuItems(reservedRoom)


  afterLoadedRoom = ->
    afterLoaded.apply(@)

    $(@).find('.room[data-order-id]').each (i, el) ->
      $el = $(el)

      $.contextMenu
        selector: "[data-order-id='#{$el.data('order-id')}']"
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


  afterLoadedRepair = ->
    afterLoaded.apply(@)

    $(@).find('.repair[data-order-id]').each (i, el) ->
      $el = $(el)
      $.contextMenu
        selector: "[data-order-id='#{$el.data('order-id')}']"
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


  afterLoadedBoxing = ->
    afterLoaded.apply(@)

    $(@).find('.boxing[data-order-id]').each (i, el) ->
      $el = $(el)
      $.contextMenu
        selector: "[data-order-id='#{$el.data('order-id')}']"
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

  ##---------------------
  ## main
  ##---------------------
  reloadSelect = -> $('#select').load '/region/selects', afterLoadedSelect
  reloadRoom   = -> $('#fitting-room').load '/region/rooms', afterLoadedRoom
  reloadRepair = -> $('#repair').load '/region/status/repair', afterLoadedRepair
  reloadBoxing = -> $('#boxing').load '/region/status/boxing', afterLoadedBoxing

  reloadSelect()
  reloadRoom()
  reloadRepair()
  reloadBoxing()
