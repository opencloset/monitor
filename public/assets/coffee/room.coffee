$ ->
  $("abbr.timeago").timeago()
  hostname = location.hostname
  port = location.port
  protocol = location.protocol
  schema = if protocol is 'https:' then 'wss:' else 'ws:'
  url = "#{schema}//#{hostname}:#{port}/socket"
  sock = new ReconnectingWebSocket url, null, { debug: false }
  sock.onopen = (e) ->
    sock.send '/subscribe order'
    sock.send '/subscribe user'
  sock.onmessage = (e) ->
    data = JSON.parse(e.data)
    sender = data.sender
    if sender is 'order' and parseInt(data.from) in [20..30] or parseInt(data.to) in [20..30]
      location.reload()
    else if sender is 'user'
      location.reload()
  sock.onerror = (e) ->
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
        $this.parent().toggleClass('active')
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
