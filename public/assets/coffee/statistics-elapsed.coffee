alert = (cls, msg, target) ->
  unless msg
    msg = cls
    cls = 'info'
  unless target
    target = 'body'
  # danger, success, info
  $(target).prepend("<div class=\"alert alert-#{cls}\"><button class=\"close\" type=\"button\" data-dismiss=\"alert\">&times;</button>#{msg}</div>")
  $('html, body').animate({ scrollTop: $(target).offset().top }, 0)

  setTimeout ->
    $('.alert').remove()
  , 8000

Date.prototype.ymd = ->
  yyyy = @getFullYear().toString()
  mm = (@getMonth() + 1).toString()
  dd = @getDate().toString()
  return yyyy + '-' + (if mm[1] then mm else "0" + mm[0]) + '-' + (if dd[1] then dd else "0"+dd[0])

names = 
  1: '방문'
  2: '치수측정'
  3: '의류선택'
  4: '탈의'
  5: '수선'
  6: '포장'
  7: '결제대기'

barChart = (data) ->
  nv.addGraph ->
    chart = nv.models.multiBarChart()
      .transitionDuration(350)
      .reduceXTicks(true)
      .rotateLabels(0)
      .showControls(false)
      .groupSpacing(0.1)
      .yDomain([0, 60])

    chart.xAxis
      .axisLabel('상태')
      .tickFormat (d) -> 
        names[d] or ''

    chart.yAxis
      .axisLabel('분')
      .tickFormat(d3.format('.02f'))

    d3.select('svg.total')
      .datum(data)
      .call(chart)

$ ->
  width = height = 300
  $('svg').css('width', width).css('height', height)
  $('svg.total').css('width', width * 5).css('height', height * 2)
  chart = nv.models.pieChart()
    .x (d) ->
      d.label.replace(/[0-9]/g, '')
    .y (d) ->
      d.value
    .width(300)
    .height(300)
    .showLabels(true)
  nv.addGraph ->
    chart

  $('.datepicker').datepicker
    language: 'kr'
    todayHighlight: true
    format: 'yyyy-mm-dd'
  .on 'changeDate', (e) ->
    ymd = e.date.ymd()
    $.ajax "/statistics/elapsed/#{ymd}.json",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        gdata = data.gdata
        d3.select('svg.male')
          .datum(gdata.daily.male)
          .transition().duration(350)
          .call(chart)
        d3.select('svg.female')
          .datum(gdata.daily.female)
          .transition().duration(350)
          .call(chart)
        barChart(gdata.bars)
        $('h4.male small').text(gdata.daily.sum.male)
        $('h4.female small').text(gdata.daily.sum.female)
      error: (jqXHR, textStatus, errorThrown) ->
        alert('danger', JSON.parse(jqXHR.responseText).error.str)
        $('svg').empty()
