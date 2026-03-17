API 文档
/api/movies
获取影片列表

method
GET

参数
参数	是否必须	可选值	默认值	说明
page	否		1	页码
magnet	否	exist
all	exist	exist: 只返回有磁力链接的影片
all: 返回全部影片
filterType	否	star
genre
director
studio
label
series		筛选类型，必须与 filterValue 一起使用
star: 演员
genre: 类别
director: 导演
studio: 制作商
label: 发行商
series: 系列
filterValue	否			筛选值，必须与 filterType 一起使用
type	否	normal
uncensored	normal	normal: 有码影片
uncensored: 无码影片
请求举例
/api/movies
返回有磁力链接的第一页影片

/api/movies?filterType=star&filterValue=rsv&magnet=all
返回演员 ID 为 rsv 的影片的第一页，包含有磁力链接和无磁力链接的影片

/api/movies?page=2&filterType=genre&filterValue=4
返回类别 ID 为 4 的影片的第二页，只返回有磁力链接的影片

/api/movies?type=uncensored
返回无码影片的第一页，只返回有磁力链接的影片

返回举例
点击展开
{
  // 影片列表
  "movies": [
    {
      "date": "2023-04-28",
      "id": "YUJ-003",
      "img": "https://www.javbus.com/pics/thumb/9n0d.jpg",
      "title": "夫には言えない三日間。 セックスレスで欲求不満な私は甥っ子に中出しさせています。 岬ななみ",
      "tags": ["高清", "字幕", "3天前新種"]
    }
    // ...
  ],
  // 分页信息
  "pagination": {
    "currentPage": 1,
    "hasNextPage": true,
    "nextPage": 2,
    "pages": [1, 2, 3]
  },
  // 筛选信息，注意：只有在请求参数包含 filterType 和 filterValue 时才会返回
  "filter": {
    "name": "岬ななみ",
    "type": "star",
    "value": "rsv"
  }
}
/api/movies/search
搜索影片

method
GET

参数
参数	是否必须	可选值	默认值	说明
keyword	是			搜索关键字
page	否		1	页码
magnet	否	exist
all	exist	exist: 只返回有磁力链接的影片
all: 返回全部影片
type	否	normal
uncensored	normal	normal: 有码影片
uncensored: 无码影片
请求举例
/api/movies/search?keyword=三上
搜索关键词为 三上 的影片的第一页，只返回有磁力链接的影片

/api/movies/search?keyword=三上&magnet=all
搜索关键词为 三上 的影片的第一页，包含有磁力链接和无磁力链接的影片

返回举例
点击展开
{
  // 影片列表
  "movies": [
    {
      "date": "2020-08-15",
      "id": "SSNI-845",
      "img": "https://www.javbus.com/pics/thumb/7t44.jpg",
      "title": "彼女の姉は美人で巨乳しかもドS！大胆M性感プレイでなす術もなくヌキまくられるドMな僕。 三上悠亜",
      "tags": ["高清", "字幕"]
    }
    // ...
  ],
  // 分页信息
  "pagination": {
    "currentPage": 2,
    "hasNextPage": true,
    "nextPage": 3,
    "pages": [1, 2, 3, 4, 5]
  },
  "keyword": "三上"
}
/api/movies/{movieId}
获取影片详情

method
GET

请求举例
/api/movies/SSIS-406
返回番号为 SSIS-406 的影片详情

返回举例
点击展开
{
  "id": "SSIS-406",
  "title": "SSIS-406 才色兼備な女上司が思う存分に羽目を外し僕を連れ回す【週末限定】裏顔デート 葵つかさ",
  "img": "https://www.javbus.com/pics/cover/8xnc_b.jpg",
  // 封面大图尺寸
  "imageSize": {
    "width": 800,
    "height": 538
  },
  "date": "2022-05-20",
  // 影片时长
  "videoLength": 120,
  "director": {
    "id": "hh",
    "name": "五右衛門"
  },
  "producer": {
    "id": "7q",
    "name": "エスワン ナンバーワンスタイル"
  },
  "publisher": {
    "id": "9x",
    "name": "S1 NO.1 STYLE"
  },
  "series": {
    "id": "xx",
    "name": "xx"
  },
  "genres": [
    {
      "id": "e",
      "name": "巨乳"
    }
    // ...
  ],
  // 演员信息，一部影片可能包含多个演员
  "stars": [
    {
      "id": "2xi",
      "name": "葵つかさ"
    }
  ],
  // 影片预览图
  "samples": [
    {
      "alt": "SSIS-406 才色兼備な女上司が思う存分に羽目を外し僕を連れ回す【週末限定】裏顔デート 葵つかさ - 樣品圖像 - 1",
      "id": "8xnc_1",
      // 大图
      "src": "https://pics.dmm.co.jp/digital/video/ssis00406/ssis00406jp-1.jpg",
      // 缩略图
      "thumbnail": "https://www.javbus.com/pics/sample/8xnc_1.jpg"
    }
    // ...
  ],
  // 同类影片
  "similarMovies": [
    {
      "id": "SNIS-477",
      "title": "クレーム処理会社の女社長 土下座とカラダで解決します 夢乃あいか",
      "img": "https://www.javbus.com/pics/thumb/4wml.jpg"
    }
    // ...
  ],
  "gid": "50217160940",
  "uc": "0"
}
/api/magnets/{movieId}
获取影片磁力链接

method
GET

参数
参数	是否必须	可选值	默认值	说明
gid	是			从影片详情获取到的 gid
uc	是			从影片详情获取到的 uc
sortBy	否	date
size	size	按照日期或大小排序，必须与 sortOrder 一起使用
sortOrder	否	asc
desc	desc	升序或降序，必须与 sortBy 一起使用
请求举例
/api/magnets/SSNI-730?gid=42785257471&uc=0
返回番号为 SSNI-730 的影片的磁力链接

/api/magnets/SSNI-730?gid=42785257471&uc=0&sortBy=size&sortOrder=asc
返回番号为 SSNI-730 的影片的磁力链接，并按照大小升序排序

/api/magnets/SSNI-730?gid=42785257471&uc=0&sortBy=date&sortOrder=desc
返回番号为 SSNI-730 的影片的磁力链接，并按照日期降序排序

返回举例
点击展开
[
  {
    "id": "17508BF5C17CBDF7C77E12DAAD1BDAB325116585",
    "link": "magnet:?xt=urn:btih:17508BF5C17CBDF7C77E12DAAD1BDAB325116585&dn=SSNI-730-C",
    // 是否高清
    "isHD": true,
    "title": "SSNI-730-C",
    "size": "6.57GB",
    // bytes
    "numberSize": 7054483783,
    "shareDate": "2021-03-14",
    // 是否包含字幕
    "hasSubtitle": true
  }
  // ...
]
/api/stars/{starId}
获取演员详情

method
GET

参数
参数	是否必须	可选值	默认值	说明
type	否	normal
uncensored	normal	normal: 有码影片演员详情
uncensored: 无码影片演员详情
请求举例
/api/stars/2xi
返回演员 葵つかさ 的详情

/api/stars/2jd?type=uncensored
返回演员 波多野結衣 的详情

返回举例
点击展开
{
  "avatar": "https://www.javbus.com/pics/actress/2xi_a.jpg",
  "id": "2xi",
  "name": "葵つかさ",
  "birthday": "1990-08-14",
  "age": "32",
  "height": "163cm",
  "bust": "88cm",
  "waistline": "58cm",
  "hipline": "86cm",
  "birthplace": "大阪府",
  "hobby": "ジョギング、ジャズ鑑賞、アルトサックス、ピアノ、一輪車"
}