# 원본 easyTravel Tomcat 이미지 위에 한글 리소스(overlay)를 덮어쓴 이미지
#   build context: i18n/ko/<component>
#   overlay/ 아래 경로 = WAR 루트 기준 경로 (예: overlay/orange.jsf, overlay/WEB-INF/classes/messages.properties)
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

COPY overlay/ /tmp/ko-overlay/

RUN set -eux; \
    find /tmp/ko-overlay -name .gitkeep -delete; \
    if [ -n "$(ls -A /tmp/ko-overlay)" ]; then \
      jar uf "${CATALINA_HOME}/webapps/ROOT.war" -C /tmp/ko-overlay . ; \
    fi; \
    rm -rf /tmp/ko-overlay; \
    # 한글 처리를 위한 JVM 기본 인코딩/로케일 (CATALINA_OPTS 는 Deployment 에서 덮어쓰므로 setenv.sh 사용)
    printf '%s\n' 'export JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8 -Duser.language=ko -Duser.country=KR"' \
      > "${CATALINA_HOME}/bin/setenv.sh"; \
    chmod +x "${CATALINA_HOME}/bin/setenv.sh"

LABEL org.opencontainers.image.description="Dynatrace easyTravel (Korean UI overlay)"
