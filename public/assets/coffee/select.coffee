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
    e.preventDefault()
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

  $('span.order-status.label').each (i, el) ->
    $(el).addClass OpenCloset.status[ $(el).data('order-detail-status') ].css

Window::OpenCloset =
  status:
    '대여가능':   { id: 1,  css: 'label-success'   }
    '대여중':     { id: 2,  css: 'label-important' }
    '대여불가':   { id: 3,  css: 'label-primary'   }
    '예약':       { id: 4,  css: 'label-primary'   }
    '세탁':       { id: 5,  css: 'label-primary'   }
    '수선':       { id: 6,  css: 'label-primary'   }
    '분실':       { id: 7,  css: 'label-primary'   }
    '폐기':       { id: 8,  css: 'label-primary'   }
    '반납':       { id: 9,  css: 'label-primary'   }
    '부분반납':   { id: 10, css: 'label-warning'   }
    '반납배송중': { id: 11, css: 'label-warning'   }
    '방문안함':   { id: 12, css: 'label-warning'   }
    '방문':       { id: 13, css: 'label-warning'   }
    '방문예약':   { id: 14, css: 'label-info'      }
    '배송예약':   { id: 15, css: 'label-info'      }
    '치수측정':   { id: 16, css: 'label-primary'   }
    '의류준비':   { id: 17, css: 'label-primary'   }
    '포장':       { id: 18, css: 'label-primary'   }
    '결제대기':   { id: 19, css: 'label-primary'   }
    '탈의01':     { id: 20, css: 'label-primary'   }
    '탈의02':     { id: 21, css: 'label-primary'   }
    '탈의03':     { id: 22, css: 'label-primary'   }
    '탈의04':     { id: 23, css: 'label-primary'   }
    '탈의05':     { id: 24, css: 'label-primary'   }
    '탈의06':     { id: 25, css: 'label-primary'   }
    '탈의07':     { id: 26, css: 'label-primary'   }
    '탈의08':     { id: 27, css: 'label-primary'   }
    '탈의09':     { id: 28, css: 'label-primary'   }
    '탈의10':     { id: 29, css: 'label-primary'   }
    '탈의11':     { id: 30, css: 'label-primary'   }
    '대여안함':   { id: 40, css: 'label-primary'   }
