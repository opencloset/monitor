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
  sock.onmessage = (e) ->
    data = JSON.parse(e.data)
    console.log data
    sender = data.sender
    if sender is 'order' and parseInt(data.from) is 6 or parseInt(data.to) is 6
      location.reload()
  sock.onerror = (e) ->
    location.reload()
