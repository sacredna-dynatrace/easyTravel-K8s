// MongoDB 여행상품 표시 텍스트 한글화 스크립트 (mongo 3.4 shell, ES5 문법)
// 원칙: 도시/지역명(location)은 loadgen 검색 시나리오가 영문으로 입력하므로 변경하지 않는다.
// 번역 사전은 i18n-source 브랜치의 mongodb/*.json 을 분석한 뒤 채운다. (2단계에서 작성)
var DB_NAME = "easyTravel";        // i18n-source/mongodb/_databases.txt 확인 후 확정
var db2 = db.getSiblingDB(DB_NAME);

// { collection: { field: { "영문": "한글" } } }
var DICT = {
  // "Journey": { "description": { "...": "..." } },
};

Object.keys(DICT).forEach(function (col) {
  Object.keys(DICT[col]).forEach(function (field) {
    var map = DICT[col][field];
    Object.keys(map).forEach(function (en) {
      var q = {}; q[field] = en;
      var u = { $set: {} }; u.$set[field] = map[en];
      var r = db2.getCollection(col).updateMany(q, u);
      print(col + "." + field + " : " + en + " -> " + map[en] + " (" + r.modifiedCount + ")");
    });
  });
});
