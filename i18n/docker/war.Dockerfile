# 원본 easyTravel Tomcat 이미지의 ROOT.war 를 한글화된 WAR 로 교체
#   build context: workflow 가 만든 임시 디렉터리 (patch_archive.py 결과 ROOT.war 포함)
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

COPY ROOT.war /usr/local/tomcat/webapps/ROOT.war

# 한글 처리를 위한 JVM 기본 인코딩. 로케일(user.language)은 바꾸지 않음
#   → 통화($)·날짜 형식과 loadgen 입력 형식(MMM dd, yyyy)을 원본과 동일하게 유지
# CATALINA_OPTS 는 Deployment 에서 지정하므로 setenv.sh 의 JAVA_OPTS 로 추가
RUN printf '%s\n' 'export JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"' \
      > /usr/local/tomcat/bin/setenv.sh \
 && chmod +x /usr/local/tomcat/bin/setenv.sh

LABEL org.opencontainers.image.description="Dynatrace easyTravel (Korean UI)"
