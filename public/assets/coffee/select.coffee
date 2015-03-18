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
  sock.onmessage = (e) ->
    data = JSON.parse(e.data)
    sender = data.sender
    if sender is 'order' and parseInt(data.from) is 17 or parseInt(data.to) is 17
      location.reload()
    else if sender is 'user'
      location.reload()
  sock.onerror = (e) ->
    location.reload()

  $("abbr.timeago").timeago()

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
        $this.toggleClass('active')
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
