statusMap =
  6:  '수선'
  13: '방문'
  16: '치수측정'
  17: '의류선택'
  18: '포장'
  19: '결제대기'
  20: '탈의'

$ ->
  $lime = "#8CBF26"
  $red = "#e5603b"
  $redDark = "#d04f4f"
  $blue = "#6a8da7"
  $green = "#56bc76"
  $orange = "#eac85e"
  $pink = "#E671B8"
  $purple = "#A700AE"
  $brown = "#A05000"
  $teal = "#4ab0ce"
  $gray = "#666"
  $white = "#fff"
  $textColor = $gray

  nv.addGraph ->
    chart = nv.models.lineChart().margin
      top: 0
      bottom: 25
      left: 25
      right: 0
    .color([$lime, $orange, $white, $green, $blue, $purple, $brown, $red, $pink, $teal, $gray, $redDark])
    chart.legend.margin({ top: 3 })
    chart.yAxis.showMaxMin(false).tickFormat(d3.format(',.f'))
    chart.xAxis.showMaxMin(false).tickFormat (d) ->
      statusMap[d]
    $.ajax '/statistics/elapsed',
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        gdata = data.gdata
        gdata[0].area = true
        d3.select('#elapsed-chart svg')
          .datum(gdata)
          .transition().duration(500)
          .call(chart)

  trend_options =
    width: '150px'
    height: '30px'
    lineColor: $white
    lineWidth: '2'
    spotRadius: '2'
    highlightLineColor: $gray
    highlightSpotColor: $gray
    spotColor: false
    minSpotColor: false
    maxSpotColor: false

  i = 0
  lineColors = [$green, $orange, $blue, $red, $white]
  fillColors = ['rgba(86, 188, 118, 0.1)', 'rgba(234, 200, 94, 0.1)', 'rgba(106, 141, 167, 0.1)', 'rgba(229, 96, 59, 0.1)', 'rgba(255, 255, 255, 0.1)']
  ptr = 0
  $('.chart-cell').each ->
    $this = $(@)
    data = $this.data('trend')
    trend_options.lineColor = lineColors[ptr]
    trend_options.fillColor = fillColors[ptr++]
    $this.sparkline(data, trend_options)
