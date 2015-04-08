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
    range = [20..30]
    range.unshift 17
    if sender is 'order' and parseInt(data.from) in range or parseInt(data.to) in range
      location.reload()
    else if sender is 'user'
      location.reload()
  sock.onerror = (e) ->
    location.reload()

  $("abbr.timeago").timeago()
