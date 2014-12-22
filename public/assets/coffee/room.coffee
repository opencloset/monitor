$ ->
  $("abbr.timeago").timeago()
  hostname = location.hostname
  port = location.port
  protocol = location.protocol
  schema = if protocol is 'https:' then 'wss:' else 'ws:'
  url = "#{schema}//#{hostname}:#{port}/socket"
  count = 0
  sock = new ReconnectingWebSocket url, null, { debug: false }
  sock.onmessage = (e) ->
    location.reload() if count++ > 10
    data = JSON.parse(e.data)
    if parseInt(data.from) in [20..30] or parseInt(data.to) in [20..30]
      location.reload()
  sock.onerror = (e) ->
    location.reload()
