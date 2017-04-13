$ ->
  suggestion = new Bloodhound
    datumTokenizer: Bloodhound.tokenizers.obj.whitespace('phone')
    queryTokenizer: Bloodhound.tokenizers.whitespace
    remote:
      url: "#{location.pathname}/search?q=%QUERY"
      wildcard: '%QUERY'

  $('#query.typeahead').typeahead null,
    name: 'q'
    display: 'phone'
    source: suggestion
    limit: 10
    templates:
      empty: [
        '<div class="empty-message">',
          '검색결과가 없습니다',
        '</div>'
      ].join('\n')
      suggestion: (data) ->
        template = JST['reservation/typeahead-query']
        html     = template(data)
        return html

  $('#query.typeahead').on 'typeahead:select', (e, data) ->
    template = JST['reservation/typeahead-select']
    html     = template(data)
    $('#selected').html(html)
