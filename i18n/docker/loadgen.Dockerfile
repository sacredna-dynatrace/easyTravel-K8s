# headless loadgen 의 uemload.jar 를 한글 UI 용 selector 로 패치한 버전으로 교체
#   build context: workflow 가 만든 임시 디렉터리 (patch_archive.py 결과 uemload.jar 포함)
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
COPY uemload.jar /easytravel/uemload.jar
LABEL org.opencontainers.image.description="Dynatrace easyTravel headless loadgen (Korean UI selectors)"
