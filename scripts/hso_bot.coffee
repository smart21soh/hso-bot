# Description:
#   For get realtime searching keyword in naver
#
# Dependencies:
#  "hubot": "^2.13.2",
#  "hubot-diagnostics": "0.0.1",
#  "hubot-google-images": "^0.1.5",
#  "hubot-google-translate": "^0.2.0",
#  "hubot-help": "^0.1.1",
#  "hubot-heroku-keepalive": "0.0.4",
#  "hubot-maps": "0.0.2",
#  "hubot-pugme": "^0.1.0",
#  "hubot-redis-brain": "0.0.3",
#  "hubot-rules": "^0.1.1",
#  "hubot-scripts": "^2.16.1",
#  "hubot-shipit": "^0.2.0",
#  "hubot-slack": "^3.3.0",
#  "htmlparser": "1.7.7",
#  "soupselect": "0.2.0",
#  "underscore": "1.8.3",
#  "underscore.string": "3.1.1"
#  "heroku-self-ping": "1.1.1"
#
# Configuration:
#   NOTING
#
# Commands:
# startNaver                 : realtime searching keyword in naver schedualer start."
# stopNaver                  : realtime searching keyword in naver schedualer stop."
# set interval time '$time'  : set time interval with naver realtime searching keyword schedualer."
# get interval time          : get time interval with naver realtime searching keyword schedualer."
# show naver                 : show realtime searching keyword in naver"
# search '$searchEngine' '$keyword' \n : 웹 서치 ex) search google jjaekjjaek.
#
# Notes:
#
#
# Author:
#   Hwang Sun Oh
#   smart21soh@naver.com
#   http://jjaekjjaek.tistory.com

_           = require("underscore")
_s          = require("underscore.string")
Select      = require("soupselect").select
HTMLParser  = require("htmlparser")

require('heroku-self-ping')("https://hso-bot.herokuapp.com/")

module.exports = (robot) ->

  #지역 변수들 선언
  intervalObject = null
  intervalTime = 1800000
  numuricPattern = new RegExp /^\d+$/

  robot.hear /q/i, (response) ->
    robot.http("http://www.telize.com/geoip?")
      .get() (err, res, body) ->
        json = JSON.parse(body)
        switch res.statusCode
          when 200
            lot = json.longitude
            lat = json.latitude
            rs = dfs_xy_conv("toXY", lat, lot)
            #response.send xml2jsonCurrentWth(rs.nx, rs.ny, robot)
            console.log xml2jsonCurrentWth(rs.nx, rs.ny, robot)
          else
            response.send "There was an error getting external IP (status: #{res.statusCode})."


  #봇 호출 선언 부
  robot.respond /show commands/i, (response) ->
    resultTxt ="
1. startNaver                 : 네이버 실시간 검색어 스케쥴링 시작.\n
2. stopNaver                  : 네이버 실시간 검색어 스케쥴링 중지.\n
3. set interval time '$time'\n                              : 네이버 실시간 검색어 스케쥴링 시간 설정 (단위:ms).\n
4. get interval time          : 네이버 실시간 검색어 스케쥴링 시간 확인.\n
5. show naver                 : 네이버 실시간 검색어 조회.\n
6. search '$searchEngine' '$keyword' \n                              : 웹 서치 ex) search google jjaekjjaek.\n
"
    response.reply resultTxt

  robot.respond /startNaver/i, (response) ->
    startNaver (response)

  robot.respond /stopNaver/i, (response) ->
    stopNaver (response)

  robot.respond /set interval time (.*)/i, (response) ->
    setTime = response.match[1]

    if setTime.match numuricPattern
      intervalTime = setTime
      response.reply "스케쥴링 시간 설정 값 : #{setTime}ms"

      if intervalObject != null
        stopNaver (response)

      startNaver (response)
    else
      response.reply "숫자만 입력해 주세요 (단위 : millisecond)"


  robot.respond /get interval time/i, (response) ->
    response.reply "현재 스케쥴링 설정 시간 : #{intervalTime}ms"

  robot.respond /show naver/i, (response) ->
    robot.http("http://www.naver.com")
    .header('User-Agent', 'Hubot Wikipedia Script')
    .get() (err, res, body) ->
      if err
        response.reply "get Error...  #{err}"
        return

      if res.statusCode is 301
        response.reply res.headers.location
        return

      paragraphs = parseHTML(body, "noscript")
      response.send "네이버 실시간 검색어 입니다. :"
      findBestParagraph(paragraphs, response)

  robot.respond /search (.*)/i, (response) ->
    inputParam = response.match[1]
    searchResult = searchWeb (inputParam)

    if searchResult == undefined
      response.reply "검색 가능한 사이트를 적어주세요. (google, naver, daum, yahoo, bing)"
    else if searchResult == null
      response.reply "검색할 단어를 입력해주세요 ex) search google jjaekjjaek"
    else
      response.reply searchResult



  # 자체 함수 선언 부
  startNaver = (response) ->
    if intervalObject
      response.reply "이미 스케쥴링 중입니다...."
      return

    response.reply "네이버 실시간 검색어 스케쥴링 시작..."
    intervalObject = setInterval () ->
      callNaver (response)
    , intervalTime

  stopNaver = (response) ->
    if intervalObject
      clearInterval(intervalObject)
      response.reply "네이버 실시간 검색어 스케쥴링 중지..."
      intervalObject = null
    else
      response.reply "이미 스케쥴링이 중지되어있습니다."

  callNaver = (response) ->
    robot.http("http://www.naver.com")
    .header('User-Agent', 'Hubot naver real-time search Script')
    .get() (err, res, body) ->
      if err
        response.send "get Error...  #{err}"
        return

      if res.statusCode is 301
        response.send res.headers.location
        return

      paragraphs = parseHTML(body, "noscript")
      response.send "네이버 실시간 검색어 입니다. :"
      findBestParagraph(paragraphs, response)

  searchWeb = (inputParam) ->
    iParamArr = inputParam.split " "
    type = iParamArr[0]
    keyword = iParamArr[1]

    if keyword == undefined
      url = null
      return url

    if type == 'google'
      url = "https://www.google.co.kr/webhp?hl=ko#newwindow=1&safe=off&hl=ko&q=#{keyword}"
    else if type == 'naver'
      url = "http://search.naver.com/search.naver?sm=tab_hty.top&where=nexearch&ie=utf8&query=#{keyword}"
    else if type == 'daum'
      url = "http://search.daum.net/search?w=tot&DA=YZR&t__nil_searchbox=btn&sug=&sugo=&o=&q=#{keyword}"
    else if type == 'yahoo'
      url = "https://search.yahoo.com/search;_ylt=A86.ItQsBp1VvdsAj0SbvZx4?&toggle=1&cop=mss&ei=UTF-8&fr=yfp-t-328&fp=1&p=#{keyword}"
    else if type == 'bing'
      url = "http://www.bing.com/search?form=PRKRKO&refig=857ee60d3714404fa7a5d4dde57f0bb8&pq=china&sc=0-0&sp=-1&qs=n&sk=&q=#{keyword}"

    url


  # 유틸 함수 선언
  childrenOfType = (root, nodeType) ->
    return [root] if root?.type is nodeType

    if root?.children?.length > 0
      return (childrenOfType(child, nodeType) for child in root.children)

    []

  findBestParagraph = (paragraphs, response) ->
    return null if paragraphs.length is 0

    childs = _.flatten childrenOfType(paragraphs[0], 'text')
    url = 'http://search.naver.com/search.naver?sm=tab_hty.top&where=nexearch&ie=utf8&query='

    i = 0
    text = "";
    while i < childs.length
      cArr = childs[i].data.split ':'
      val = encodeURIComponent cArr[1].replace /^\s+|\s+$/g, ""
      response.reply  "#{cArr[0]} \n #{url+val}"
      i++

    text


  parseHTML = (html, selector) ->
    handler = new HTMLParser.DefaultHandler((() ->),
      ignoreWhitespace: true
    )
    parser  = new HTMLParser.Parser handler
    parser.parseComplete html

    Select handler.dom, selector

  # LCC DFS 좌표변환을 위한 기초 자료
  RE = 6371.00877
  # 지구 반경(km)
  GRID = 5.0
  # 격자 간격(km)
  SLAT1 = 30.0
  # 투영 위도1(degree)
  SLAT2 = 60.0
  # 투영 위도2(degree)
  OLON = 126.0
  # 기준점 경도(degree)
  OLAT = 38.0
  # 기준점 위도(degree)
  XO = 43
  # 기준점 X좌표(GRID)
  YO = 136
  # dfs_xy_conv
  # 기준점 Y좌표(GRID)
  # LCC DFS 좌표변환 ( code : "toXY"(위경도->좌표, v1:위도, v2:경도), "toLL"(좌표->위경도,v1:x, v2:y) )

  dfs_xy_conv = (code, v1, v2) ->
    DEGRAD = Math.PI / 180.0
    RADDEG = 180.0 / Math.PI
    re = RE / GRID
    slat1 = SLAT1 * DEGRAD
    slat2 = SLAT2 * DEGRAD
    olon = OLON * DEGRAD
    olat = OLAT * DEGRAD
    sn = Math.tan(Math.PI * 0.25 + slat2 * 0.5) / Math.tan(Math.PI * 0.25 + slat1 * 0.5)
    sn = Math.log(Math.cos(slat1) / Math.cos(slat2)) / Math.log(sn)
    sf = Math.tan(Math.PI * 0.25 + slat1 * 0.5)

    # sf = sf ** sn * Math.cos(slat1) / sn
    sf = Math.pow(sf, sn) * Math.cos(slat1) / sn

    ro = Math.tan(Math.PI * 0.25 + olat * 0.5)

    # ro = re * sf / ro ** sn
    ro = re * sf / Math.pow(ro, sn)

    rs = {}
    if code == 'toXY'
      rs['lat'] = v1
      rs['lng'] = v2
      ra = Math.tan(Math.PI * 0.25 + v1 * DEGRAD * 0.5)

      # ra = re * sf / ra ** sn
      ra = re * sf / Math.pow(ra, sn)

      theta = v2 * DEGRAD - olon
      if theta > Math.PI
        theta -= 2.0 * Math.PI
      if theta < -Math.PI
        theta += 2.0 * Math.PI
      theta *= sn
      rs['nx'] = Math.floor(ra * Math.sin(theta) + XO + 0.5)
      rs['ny'] = Math.floor(ro - (ra * Math.cos(theta)) + YO + 0.5)
    else
      rs['nx'] = v1
      rs['ny'] = v2
      xn = v1 - XO
      yn = ro - v2 + YO
      ra = Math.sqrt(xn * xn + yn * yn)
      if sn < 0.0
        -ra

      # alat = (re * sf / ra) ** (1.0 / sn)
      alat = Math.pow(re * sf / ra, 1.0 / sn)

      alat = 2.0 * Math.atan(alat) - (Math.PI * 0.5)
      if Math.abs(xn) <= 0.0
        theta = 0.0
      else
        if Math.abs(yn) <= 0.0
          theta = Math.PI * 0.5
          if xn < 0.0
            -theta
        else
          theta = Math.atan2(xn, yn)
      alon = theta / sn + olon
      rs['lat'] = alat * RADDEG
      rs['lng'] = alon * RADDEG
    rs

# xml2jsonCurrentWth
xml2jsonCurrentWth = (nx, ny, robot) ->
  `var today`
  today = new Date
  dd = today.getDate()
  mm = today.getMonth() + 1
  yyyy = today.getFullYear()
  hours = today.getHours()
  minutes = today.getMinutes()
  if minutes < 30
    # 30분보다 작으면 한시간 전 값
    hours = hours - 1
    if hours < 0
      # 자정 이전은 전날로 계산
      today.setDate today.getDate() - 1
      dd = today.getDate()
      mm = today.getMonth() + 1
      yyyy = today.getFullYear()
      hours = 23
  if hours < 10
    hours = '0' + hours
  if mm < 10
    mm = '0' + mm
  if dd < 10
    dd = '0' + dd
  _nx = nx
  _ny = ny
  apikey = 'Emz8CfMLIHnIeD7Hl6qDBtzOB5Mpt3Sgh8G9ol07R4yzQ3ffyNDX%2BTdekwX6KD2utTd7q8UbAik%2B8pgk7w3bug%3D%3D'
  today = yyyy + '' + mm + '' + dd
  basetime = hours + '00'
  fileName = 'http://newsky2.kma.go.kr/service/SecndSrtpdFrcstInfoService/ForecastGrib'
  fileName += '?ServiceKey=' + apikey
  fileName += '&base_date=' + today
  fileName += '&base_time=' + basetime
  fileName += '&nx=' + _nx + '&ny=' + _ny
  fileName += '&pageNo=1&numOfRows=6'
  fileName += '&_type=json'
  # $.ajax
  #   url: fileName
  #   type: 'GET'
  #   cache: false
  #   success: (data) ->
  #     myXML = rplLine(data.responseText)
  #     indexS = myXML.indexOf('')
  #     indexE = myXML.indexOf('')
  #     result = myXML.substring(indexS + 3, indexE)
  #     jsonObj = $.parseJSON('[' + result + ']')
  #     rainsnow = jsonObj[0].response.body.items.item[0].obsrValue
  #     sky = jsonObj[0].response.body.items.item[4].obsrValue
  #     temp = jsonObj[0].response.body.items.item[5].obsrValue
  #     contentText = document.getElementById('content')
  #     contentText.innerHTML = sky + ' / ' + rainsnow + ' / ' + temp
  #     return
  #   error: (request, status, error) ->
  #     alert '다시 시도해주세요.\n' + 'code:' + request.status + '\n' + 'message:' + request.responseText + '\n' + 'error:' + error
  #     return

  
  robot.http(fileName)
    .get() (err, res, body) ->
      json = JSON.parse(body)
      switch res.statusCode
        when 200

          if body.responseText == undefined
            return "Can't connect to weather cast service..."

          myXML = rplLine(body.responseText)
          indexS = myXML.indexOf('')
          indexE = myXML.indexOf('')
          result = myXML.substring(indexS + 3, indexE)
          jsonObj = JSON.parse('[' + result + ']')
          rainsnow = jsonObj[0].response.body.items.item[0].obsrValue
          sky = jsonObj[0].response.body.items.item[4].obsrValue
          temp = jsonObj[0].response.body.items.item[5].obsrValue
          return "#{sky} / #{rainsnow} / #{temp}"
        else
          return "There was an error getting weather info (status: #{res.statusCode})."


# rplLine
rplLine = (value) ->
  if value != null and value != '' and value != undefined
    value.replace /\n/g, '\\n'
  else
    value
