// MongoDB 여행상품 표시 텍스트 한글화 (mongo 3.4 shell, ES5 문법)
//   i18n 2) Build Korean images workflow 가 원본 DB 에 적용한 뒤 데이터 파일을 다시 묶어 -ko 이미지로 만든다.
// 원칙
//   - 도시/지역명(LocationCollection, journey.start/destination)은 loadgen 이 영문으로 검색하므로 변경하지 않음
//   - "City - City" 형태로 자동 생성된 여행 이름도 도시명이므로 유지
//   - 여행사(Tenant) _id 는 키(로그인 ID)이므로 유지하고 description 만 번역
var db2 = db.getSiblingDB("easyTravel-Business");

// 추천/프로모션용 여행 상품 이름
var JOURNEY_NAMES = {
  "Paris - City of love": "파리 - 사랑의 도시",
  "Mauritius - Island of dreams": "모리셔스 - 꿈의 섬",
  "Going to San Francisco...": "샌프란시스코로 떠나요...",
  "Walk on the Great Wall of China": "만리장성 걷기",
  "Business Trip": "출장 패키지",
  "Honeymoon Extravaganza": "화려한 허니문",
  "Adventure Tour": "어드벤처 투어",
  "Across New Zealand": "뉴질랜드 횡단 여행",
  "Walk in the Jungle": "정글 탐험",
  "Weekend Trip into the Orient": "동양으로 떠나는 주말 여행",
  "Sport on the Beach": "해변 스포츠",
  "Party at the Pool": "풀 파티",
  "France - l'art de vivre": "프랑스 - 삶의 예술",
  "Visit the world famous Bazar": "세계적인 바자르 탐방",
  "Visit Turkey and enjoy the Beach": "튀르키예 여행과 해변 휴식"
};

// 여행사 설명
var TENANT_DESCRIPTIONS = {
  "Online and offline travel booking.": "온라인·오프라인 여행 예약.",
  "Customzied travel offerings.": "맞춤형 여행 상품.",
  "Worldwide provider of travels.": "전 세계 여행 상품 제공.",
  "Your provider for customized travel offerings.": "맞춤형 여행 상품 전문 여행사."
};

function apply(col, field, map) {
  var total = 0;
  Object.keys(map).forEach(function (en) {
    var q = {}; q[field] = en;
    var u = { $set: {} }; u.$set[field] = map[en];
    var r = db2.getCollection(col).updateMany(q, u);
    total += r.modifiedCount;
  });
  print(col + "." + field + " : " + total + " documents updated");
  return total;
}

var n = 0;
n += apply("JourneyCollection", "name", JOURNEY_NAMES);
apply("BookingCollection", "journey.name", JOURNEY_NAMES);
apply("TenantCollection", "description", TENANT_DESCRIPTIONS);
apply("JourneyCollection", "tenant.description", TENANT_DESCRIPTIONS);
apply("BookingCollection", "journey.tenant.description", TENANT_DESCRIPTIONS);

if (n === 0) {
  print("ERROR: no journey names were translated - check source data");
  quit(1);
}
