$ ->
  width = height = 300
  $('svg').css('width', width).css('height', height)
  nv.addGraph ->
    chart = nv.models.pieChart()
      .x (d) ->
        d.label.replace(/[0-9]/g, '')
      .y (d) ->
        d.value
      .width(300)
      .height(300)
      .showLabels(true)
    $.ajax '/statistics/elapsed',
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        gdata = data.gdata
        d3.select('#elapsed-chart svg.male')
          .datum(gdata['male'])
          .transition().duration(350)
          .call(chart)
        d3.select('#elapsed-chart svg.female')
          .datum(gdata['female'])
          .transition().duration(350)
          .call(chart)
