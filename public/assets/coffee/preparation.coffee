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
  sock.onmessage = (e) ->
    data = JSON.parse(e.data)
    sender = data.sender
    range = [20..30]
    range.unshift 17
    range.unshift 6
    if sender is 'order' and parseInt(data.from) in range or parseInt(data.to) in range
      location.reload()
    else if sender is 'user'
      location.reload()
    else if sender is 'active.room'
      $('#fitting-room .active').removeClass('active')
      keys = _.keys data.data
      _.each keys, (el) ->
        if el
          $("[data-order-id=#{el}]").addClass('active')
    else if sender is 'active.select'
      $('#select .active').removeClass('active')
      keys = _.keys data.data
      _.each keys, (el) ->
        if el
          $("[data-order-id=#{el}]").addClass('active')
  sock.onerror = (e) ->
    location.reload()

  $("abbr.timeago").timeago()

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

  # refs Window::OpenCloset::status in opencloset/coffee/bundle.coffee
  items = {}
  _.each [1..11], (el, i) ->
    items[el] =
      name: "탈의##{el}"
      callback: (key, opt) ->
        postStatus(key, opt, parseInt(el) + 19)

  $.contextMenu
    selector: '.select[data-order-id]'
    items: items

  $.contextMenu
    selector: '[data-order-id]:not(.select)'
    items:
      a:
        name: '의류준비'
        callback: (key, opt) ->
          postStatus(key, opt, 17)
      b:
        name: '수선'
        callback: (key, opt) ->
          postStatus(key, opt, 6)
      c:
        name: '포장'
        callback: (key, opt) ->
          postStatus(key, opt, 18)

  postStatus = (key, opt, to) ->
    $el      = opt.$trigger
    order_id = $el.data('order-id')
    $.ajax "/api/orders/#{order_id}.json",
      type: 'PUT'
      data:
        status_id: to
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        location.reload true
      complete: (jqXHR, textStatus) ->

  $('#repair .btn-success').click (e) ->
    e.preventDefault()
    url = $(@).attr('href')
    $.ajax url,
      type: 'PUT'
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        location.reload true
      complete: (jqXHR, textStatus) ->
