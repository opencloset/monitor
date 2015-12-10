$ ->
  $("abbr.timeago").timeago()

  # phonenumber suggestion
  address = new Bloodhound
    datumTokenizer: Bloodhound.tokenizers.obj.whitespace('phone')
    queryTokenizer: Bloodhound.tokenizers.whitespace
    remote:
      url: '/address?q=%QUERY'
      wildcard: '%QUERY'

  $('#q.typeahead').typeahead null,
    name: 'q'
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
