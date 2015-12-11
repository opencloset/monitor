$ ->
  $("abbr.timeago").timeago()

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
