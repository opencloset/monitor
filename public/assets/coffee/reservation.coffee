# common
import "./_common.coffee"

import "jquery.growl"
import "jquery.growl/stylesheets/jquery.growl.css"
import "jquery-mask-plugin"
import "../extlib/keypad/jquery.keypad.js"
import "../extlib/keypad/jquery.keypad.css"

# reservation-layout
import "../less/reservation.less"

$ ->
  $('#query').mask('000-0000-0000')

  $('#keypad').keypad
    submitButtonText: '검색'
    deleteButtonText: '지우기'

  $('#keypad').submit (e) ->
    e.preventDefault()
    query = $('#query').val()
    $.ajax "#{location.pathname}/search?q=#{query}",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        unless data.length
          $.growl.error({ title: '알림', message: '검색결과가 없습니다.' })
          return

        # template = JST['reservation/typeahead-select']
        template = require('../jst/reservation/typeahead-select.html')
        html     = template(data[0])
        $('#selected').html(html)
        $('#keypad').hide()
      error: (jqXHR, textStatus, errorThrown) ->
        msg = jqXHR.responseJSON.error.str
        $.growl.error({ title: '알림', message: msg })
      complete: (jqXHR, textStatus) ->
