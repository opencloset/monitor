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
      $($("[data-order-id=#{data.order_id}]")).toggleClass('active')
    else if sender is 'active.select'
      $($("[data-order-id=#{data.order_id}]")).toggleClass('active')
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

  updateOrder = (order_id, params) ->
    $.ajax "/api/orders/#{order_id}.json",
      type: 'PUT'
      data: params
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
