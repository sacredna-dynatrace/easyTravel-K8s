# 한글 여행상품 데이터가 반영된 MongoDB 이미지
#   build context: workflow 가 만든 임시 디렉터리 (translate.js 적용 후 다시 묶은 easyTravel-mongodb-db.tar.gz)
# 원본 runmongo.sh 는 기동 시마다 /tmp/easyTravel-mongodb-db.tar.gz 를 풀어서 사용하므로 이 파일만 교체하면 됨
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
COPY easyTravel-mongodb-db.tar.gz /tmp/easyTravel-mongodb-db.tar.gz
LABEL org.opencontainers.image.description="Dynatrace easyTravel MongoDB (Korean content)"
