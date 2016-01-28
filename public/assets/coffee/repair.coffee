"use strict"
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
    sock.send '/subscribe brain'
  sock.onmessage = (e) ->
    data   = JSON.parse(e.data)
    sender = data.sender
    if sender is 'brain'
      $('.repair-done').removeClass('text-success')
      ids = _.keys data.brain
      _.each ids, (order_id) ->
        $("li.repair[data-order-id=\"#{order_id}\"] .repair-done").addClass('text-success')
    return if sender isnt 'order'
    if parseInt(data.from) is 6 or parseInt(data.to) is 6
      return location.reload()

    $.ajax "/repair",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        male   = data.waiting.male
        female = data.waiting.female
        keys = _.union _.keys(male), _.keys(female)
        $("#dashboard-repair tbody span.male").empty()
        $("#dashboard-repair tbody span.female").empty()
        for key in keys
          $td = $("#dashboard-repair tbody td[data-status=\"#{key}\"]")
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

  $('.repair-done').on 'click', ->
    $this = $(@)
    order_id = $this.closest('li.repair').data('order-id')
    $.ajax "/events",
      type: 'POST'
      data: { sender: 'brain', ns: 'repair', key: order_id }
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
