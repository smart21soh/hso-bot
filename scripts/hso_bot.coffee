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
#  "heroku-self-ping": "1.1.1" (deprecated... it makes force stop in heroku dyno...)
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
Redis       = require("redis")
Url         = require("url")

#require('heroku-self-ping')("https://hso-bot.herokuapp.com/")

apikey = process.env.WEATHER_API_TOKEN

module.exports = (robot) ->

  #지역 변수들 선언
  intervalObject  = null
  intervalTime    = 1800000
  numuricPattern  = new RegExp /^\d+$/
  brainKey        = "hubot:brain"
  memberKey       = "hubot:member"
########################################################################################################################################################

  #redis init
  redisUrl = if process.env.REDISTOGO_URL?
               redisUrlEnv = "REDISTOGO_URL"
               process.env.REDISTOGO_URL
             else if process.env.REDISCLOUD_URL?
               redisUrlEnv = "REDISCLOUD_URL"
               process.env.REDISCLOUD_URL
             else if process.env.BOXEN_REDIS_URL?
               redisUrlEnv = "BOXEN_REDIS_URL"
               process.env.BOXEN_REDIS_URL
             else if process.env.REDIS_URL?
               redisUrlEnv = "REDIS_URL"
               process.env.REDIS_URL
             else
               'redis://localhost:6379'

  if redisUrlEnv?
    robot.logger.info "hubot-redis-brain: Discovered redis from #{redisUrlEnv} environment variable"
  else
    robot.logger.info "hubot-redis-brain: Using default redis on localhost:6379"


  info   = Url.parse redisUrl, true
  client = if info.auth then Redis.createClient(info.port, info.hostname, {no_ready_check: true}) else Redis.createClient(info.port, info.hostname)
  prefix = info.path?.replace('/', '') or 'hubot'

  robot.brain.setAutoSave false

  getData = ->
    client.get "#{prefix}:storage", (err, reply) ->
      if err
        throw err
      else if reply
        robot.logger.info "hubot-redis-brain: Data for #{prefix} brain retrieved from Redis"
        robot.brain.mergeData JSON.parse(reply.toString())
      else
        robot.logger.info "hubot-redis-brain: Initializing new data for #{prefix} brain"
        robot.brain.mergeData {}

      robot.brain.setAutoSave true

  if info.auth
    client.auth info.auth.split(":")[1], (err) ->
      if err
        robot.logger.error "hubot-redis-brain: Failed to authenticate to Redis"
      else
        robot.logger.info "hubot-redis-brain: Successfully authenticated to Redis"
        getData()

  client.on "error", (err) ->
    if /ECONNREFUSED/.test err.message

    else
      robot.logger.error err.stack

  client.on "connect", ->
    robot.logger.debug "hubot-redis-brain: Successfully connected to Redis"
    getData() if not info.auth

  robot.brain.on 'save', (data = {}) ->
    client.set "#{prefix}:storage", JSON.stringify data

  robot.brain.on 'close', ->
    client.quit()

  # show redis keys.... for test
  client.keys "*", (err, replies) ->
    if err
      console.log "error : #{err}"
    else
      console.log "#{replies.length} replies :"
      replies.forEach (reply, i) ->
        console.log "     #{i} : #{reply}"
###########################################################################################################################################################

  #봇 호출 선언 부
  robot.respond /show commands/i, (response) ->
    resultTxt ="\n
1. startNaver\n
-> 네이버 실시간 검색어 스케쥴링 시작.\n\n

2. stopNaver\n
-> 네이버 실시간 검색어 스케쥴링 중지.\n\n

3. set interval time '$time'\n
-> 네이버 실시간 검색어 스케쥴링 시간 설정 (단위:ms).\n\n

4. get interval time\n
-> 네이버 실시간 검색어 스케쥴링 시간 확인.\n\n

5. show naver\n
-> 네이버 실시간 검색어 조회.\n\n

6. search '$searchEngine' '$keyword' \n
-> 웹 서치 ex) search google jjaekjjaek.\n\n

7. 날씨\n
-> 접속한 클라이언트의 현재 날씨.\n\n

8. transit directions from '$출발지' to '$도착지'\n
-> 구글 맵스를 이용한 국내 경로 찾기 ex) transit directions from suwon to seoul\n\n

9. register\n
-> bot에 자신의 정보를 저장하는 명령어들 사용법 보여줌.
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


  robot.respond /날씨/i, (response) ->
    robot.http("http://www.telize.com/geoip?")
      .get() (err, res, body) ->
        json = JSON.parse(body)
        switch res.statusCode
          when 200
            response.reply "\nip : #{json.ip}\n국가 : #{json.country}\nisp(인터넷공급업체) : #{json.isp}\n위도 : #{json.latitude} 경도 : #{json.longitude}"
            # lot = json.longitude
            # lat = json.latitude
            lat = "37.57"
            lot = "126.98"
            rs = dfs_xy_conv("toXY", lat, lot)
            console.log "lat : #{rs['lat']}, lng : #{rs['lng']}"

            xml2jsonCurrentWth(rs.nx, rs.ny, robot, response)
          else
            response.reply "There was an error getting external IP (status: #{res.statusCode})."

  robot.respond /register/i, (res) ->
    res.reply "멤버정보 입력 서비스 입니다. 참고로 본인정보는 본인만 등록할 수 있습니다.\n '@#{robot.name} regMember' 를 쓴 후 나이 성별 전화번호 주소를 순서대로 띄어쓰기해서 써주세요.\nex) @#{robot.name} regMember 1살 남자 010-1234-5678 미국 히로쿠클라우드 시스템 중 어느 한곳일 듯"
    res.reply "삭제 역시 자기 정보만 지울 수 있습니다. '@#{robot.name} delMem' 을 입력해주세요."
    res.reply "등록된 멤버들을 보려면 '@#{robot.name} memList' 를 입력해주세요."
    res.reply "특정 멤버의 상세 정보를 보려면 '@#{robot.name} who is 멤버아이디' 를 입력해주세요."

  robot.respond /delMem/i, (res) ->
    userId    = res.message.user.id
    client.hdel memberKey, userId, (err, reply) ->
      if reply is 0
        res.reply "등록되지 않은 멤버입니다."
      else
        res.reply "삭제완료 !"

  robot.respond /memList/i, (res) ->
     client.hkeys memberKey, (err, replies) ->
       replies.forEach (reply, i) ->
         client.hget memberKey, reply, (err, __reply) ->
           _reply = JSON.parse __reply
           if _reply.userId is undefined
             res.reply "    #{i+1} : 이름 -> #{_reply.name}"
           else
             res.reply "   #{i+1} : 닉네임 -> #{_reply.userId}"

  robot.respond /regMember (.*)/i, (res) ->
    userId    = res.message.user.name
    name      = res.message.user.real_name
    email     = res.message.user.email_address
    id        = res.message.user.id

    paramStr  = res.match[1]
    paramArr  = paramStr.split " "
    age       = paramArr[0]
    sex       = paramArr[1]
    hp        = paramArr[2]

    i         = 3
    loc       = ''
    while i < paramArr.length
      loc += "#{paramArr[i]} "
      i++

    field     = id
    valueObj  =
      {
        "userId": userId,
        "name": name,
        "email": email,
        "age": age,
        "sex": sex,
        "hp": hp,
        "loc": loc,
        "id": id
      }

    value     = JSON.stringify valueObj

    client.hset memberKey, field, value, (err, reply) ->
      if reply is 0
        res.reply "errorrrrrrr"
      else
        res.reply "ok"

  robot.respond /who is @?([\w .\-]+)\?*$/i, (res) ->
    name = res.match[1].trim()

    client.hkeys memberKey, (err, replies) ->
      replies.forEach (reply, i) ->
        client.hget memberKey, reply, (err, __reply) ->
          _reply = JSON.parse __reply

          if _reply.userId is name
            client.hget memberKey, _reply.id, (err, reply) ->
              if reply is null
                res.reply "#{name} is not my user !!!!!!!!!!!!"
              else
                result = JSON.parse(reply)
                res.reply "#{name}님의 정보 ->\n 닉네임 : #{result.userId}\n 이름 : #{result.name}\n 나이 : #{result.age}\n 성별 : #{result.sex}\n 전화번호 : #{result.hp}\n 이메일 : #{result.email}\n slack 고유 아이디 : #{result.id}\n 거주지 : #{result.loc}"
          else
            res.reply "#{name} is not my user !!!!"


  robot.respond /save (.*) (.*)/i, (res) ->
    field = res.match[1]
    value = res.match[2]

    client.hset(brainKey, field, value)
    res.reply "save finish"

  robot.respond /get (.*)/i, (res) ->
    field = res.match[1]
    client.hget brainKey, field, (err, reply) ->
      if reply is null
        res.reply "'#{field}' dosen't have in brain.."
      else
        res.reply "brain result : #{reply.toString()}"

  robot.respond /show brain/i, (res) ->
    client.hkeys brainKey, (err, replies) ->
      replies.forEach (reply, i) ->
        res.reply "   #{i} : #{reply}"

  robot.respond /del (.*)/i, (res) ->
    field = res.match[1]
    client.hdel brainKey, field, (err, reply) ->
      if reply is 0
        res.reply "'#{field}' dosen't have in brain.."
      else
        res.reply "delete success.."


########################################################################################################################################################

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
########################################################################################################################################################


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
xml2jsonCurrentWth = (nx, ny, robot, response) ->
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
  #apikey = ''
  today = yyyy + '' + mm + '' + dd
  basetime = hours + '00'
  fileName = 'http://newsky2.kma.go.kr/service/SecndSrtpdFrcstInfoService/ForecastGrib'
  fileName += '?ServiceKey=' + apikey
  fileName += '&base_date=' + today
  fileName += '&base_time=' + basetime
  fileName += '&nx=' + _nx + '&ny=' + _ny
  fileName += '&pageNo=1&numOfRows=6'
  fileName += '&_type=json'

  robot.http(fileName, response)
    .get() (err, res, body) ->
      lgt = pty = reh = rn1 = sky = t1h = ""
      dataSelector = (jsonData) ->
        obs = jsonData.obsrValue
        switch jsonData.category
          when 'LGT' then lgt = obs
          when 'PTY' then pty = obs
          when 'REH' then reh = obs
          when 'RN1' then rn1 = obs
          when 'SKY' then sky = obs
          when 'T1H' then t1h = obs
          else console.log "unknwon code.. : #{jsonData.category}"

      data = JSON.parse(body)
      switch res.statusCode
        when 200
          if data.response.header.resultCode isnt '0000'
            response.reply data.response.header.resultMsg
            return

          jsonArr = data.response.body.items.item

          dataSelector(jsonData) for jsonData in jsonArr

          #천둥번개
          lgt = if lgt == 0 then "없음" else "있음"
          #강수형태
          pty = if pty == 0 then "없음" else if pty == 1 then "비" else if pty == 2 then "비/눈" else "눈"
          #습도
          reh = "#{reh}%"
          #1시간 강수량
          rn1 = if rn1 == 0 then "0mm" else if rn1 == 1 then "1mm 미만" else if rn1 == 5 then "1~4mm" else if rn1 == 10 then "5~9mm" else if rn1 == 20 then "10~19mm" else if rn1 == 40 then "20~39mm"else if rn1 == 70 then "40~69mm" else "70mm이상"
          #하늘 상태
          sky = if sky == 1 then "맑음" else if sky == 2 then "구름조금" else if sky ==3 then "구름많음" else "흐림"
          #기온
          t1h = "#{t1h}°C"

          response.reply "\n현재 기온 : #{t1h}\n습도 : #{reh}\n하늘 상태 : #{sky}\n강수형태 : #{pty}\n천둥번개 : #{lgt}\n한시간 강수량 : #{rn1}"

        else
          response.reply "There was an error getting weather info (status: #{res.statusCode})."
########################################################################################################################################################

# rplLine
rplLine = (value) ->
  if value != null and value != '' and value != undefined
    value.replace /\n/g, '\\n'
  else
    value
########################################################################################################################################################
