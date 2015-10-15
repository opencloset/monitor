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

  ## 10분마다 경고음을 출력
  setInterval ->
    now = Date.now()
    $("abbr.timeago").timeago().each ->
      $this = $(@)
      $this.data('')
      time = $this.attr('title')
      d = new Date("#{time}Z")
      elapsed = parseInt((now - d.getTime()) / (60 * 1000))
      if elapsed >= 10 and elapsed % 10 is 0
        $('#event audio').trigger('play')
        return false
  , 60 * 1000
