"use strict"

# common
import $ from "jquery"
import _ from "underscore"
import "bootstrap3"
import "bootstrap3/dist/css/bootstrap.min.css"
import "font-awesome5/css/fa-solid.min.css"
import "font-awesome5/css/fontawesome.min.css"
import "opencloset.css/dist/css/opencloset.min.css"

import "timeago"
import "timeago/locales/jquery.timeago.ko.js"
import "typeahead.js/dist/typeahead.jquery.js"
import Bloodhound from "typeahead.js/dist/bloodhound.js"
import ReconnectingWebSocket from "reconnectingwebsocket"

# dashboard-layout
import "jquery.growl"
import "jquery.growl/stylesheets/jquery.growl.css"
import "../less/dashboard.less"

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
    data   = JSON.parse(e.data)
    booking_date = data.order.booking.date.substr(11, 5)
    location.reload() if booking_date is '22:00'

  # phonenumber suggestion
  address = new Bloodhound
    datumTokenizer: Bloodhound.tokenizers.obj.whitespace('phone')
    queryTokenizer: Bloodhound.tokenizers.whitespace
    remote:
      url: '/address?q=%QUERY'
      wildcard: '%QUERY'

  $('#to.typeahead').typeahead null,
    name: 'to'
    display: 'phone'
    source: address
    limit: 10
    templates:
      empty: [
        '<div class="empty-message">',
          'oops, user not found',
        '</div>'
      ].join('\n')
      suggestion: (data) ->
        "<div><strong>#{data.phone}</strong> | #{data.name} | #{data.email}</div>"

  $('#to.typeahead').on 'typeahead:select', (e, data) ->
    $('#selected').html("<div><strong>#{data.phone}</strong> | #{data.name} | #{data.email}</div>")

  $('#sms-form').submit (e) ->
    e.preventDefault()
    action = $(@).attr('action')
    method = $(@).attr('method')
    data   = $(@).serialize()
    $.ajax action,
      type: method
      data: data
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $.growl.notice({ message: "메세지를 전송하였습니다" })
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ message: jqXHR.responseJSON.error.str })
      complete: (jqXHR, textStatus) ->

  smsText = '''[열린옷장] 000님 온라인 의류 대여 서비스를 이용해주셔서 감사합니다!

* 의류배송 정보: CJ대한통운/ (운송장 번호 기재)

* 반납안내

1. 택배 반납시 반납일 1일전 발송(택배비는 본인부담): oo일에 받은 상자에 담아서 보내주세요(반납 예정일: oo일)
 - 주소: 서울시 광진구 아차산로 213 (화양동, 웅진빌딩) 403호 (우.05019)
 - 전화: 02-6929-1029

2. 방문 반납시: 웅진빌딩 4층 403호
 - 반납가능시간: 월~토 am 10:00 ~ pm 6:00 ( 운영시간 후 or 휴일 반납: 4층 엘리베이터 앞 노란 무인반납함에 넣어주세요. 단, 밤10시 이후에는 빌딩 보안상 출입이 통제 됩니다.)

3. 대여기간 연장 / 연체
 - 1일 연장시 전체 대여비의 20%에 해당하는 금액이 청구됩니다.
(대여기간 연장이 필요하신 경우에는 대여시 받으신 문자메시지를 확인하여 기간연장에 필요한 정보를 입력해서 보내주세요) 
 - 연장 신청 하지 않고 연체가 발생될 경우: 1일당 전체 대여비의 30%에 해당하는 금액이 청구됩니다.

4. 대여기간 의류 손상 및 분실 배상규정
 - 의류 손상 혹은 분실의 경우에는 금액의 10배에 해당하는 금액이 청구됩니다.

열린옷장 서비스 이용에 문의사항이 있으시면, 유선/카카오톡 엘로아이디/홈페이지 통하여 문의 부탁드립니다!
감사합니다 :)'''

  $('.sms-macro').click ->
    to = $('#selected div').text()
    re = new RegExp(' ', 'g')
    text = $(@).attr('title') or smsText
    text = text.replace('000', to.split('|')[1].replace(re, '')) if to
    $('textarea[name=text]').val(text)
