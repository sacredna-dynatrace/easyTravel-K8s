<%@ taglib prefix="c" uri="http://java.sun.com/jstl/core" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>

<%-- Eliminate the automatic creation of an HTTP session when accessing to a JSP page --%>
<%@page session="false"%>

<jsp:useBean id="specialOffersBean" class="com.dynatrace.easytravel.frontend.beans.SpecialOffersBean" scope="request"/>
<html>
    <head>
        <title>특가 상품 - 랜딩 페이지</title>

        <link href="img/favicon_orange_plane.ico" rel="shortcut icon" />
        <link href="img/favicon_orange_plane.png" rel="apple-touch-icon" />

        <link href="css/BaseProd.css" rel="stylesheet" type="text/css" />
        <link href="css/footer.css" rel="stylesheet" type="text/css" />
        <link href="css/rime.css" rel="stylesheet" type="text/css" />
        <link href="css/rating.css" rel="stylesheet" type="text/css" />

        <link href="css/orange.css" rel="stylesheet" type="text/css" />
        <script src="js/jquery-1.8.1.js" type="text/javascript"></script>
        <script type="text/javascript" src="js/jquery-ui-1.8.2.min.js"></script>
        <script src="js/version.js" type="text/javascript"></script>
        <script src="js/dtagentApi.js" type="text/javascript"></script>
        <script src="js/FrameworkProd.js" type="text/javascript"></script>
        <script src="js/jquery.formLabels1.0.js" type="text/javascript"></script>
        <script src="js/headerRotation.js" type="text/javascript"></script>
        <script src="js/rating.js" type="text/javascript"></script>
        <script src="js/recommendation.js" type="text/javascript"></script>
    </head>
    <body>
        <div id="margins">
            <div xmlns="http://www.w3.org/1999/xhtml" class="header_container">

                <div class="header_content">
                    <div class="orangeHeader">
                        <div id="homelink">
                            <a href="/orange.jsf">Homelink</a>
                        </div>

                        <div class="orangeHeaderLinks">
                            <a href="/orange.jsf">홈</a><span class="orangeHeaderSeparator"></span>
                            <a href="/special-offers.jsp">특가 상품</a><span class="orangeHeaderSeparator"></span>
                            <a class="active_false" href="/about-orange.jsf">회사 소개</a><span class="orangeHeaderSeparator"></span>
                            <a class="active_false" href="/contact-orange.jsf">문의</a><span class="orangeHeaderSeparator"></span>
                            <a class="active_false" href="/legal-orange.jsf">이용약관</a><span class="orangeHeaderSeparator"></span>
                            <a class="active_false" href="/privacy-orange.jsf">개인정보처리방침</a><span class="orangeHeaderSeparator"></span>
                        </div>

                        <div class="orangeSocial">
                            <a class="iceOutLnk" href="itms-services://?action=download-manifest&amp;url=SECRET" id="j_idt37" title="iOS 앱 다운로드">
                                <img alt="iOS 앱 다운로드" src="img/apple/apple.png" /></a>
                            <a href="/apps/EasyTravelAndroid.apk" target="_blank"><img alt="Android 앱 다운로드" src="img/androidbutton.png"/></a>
                            <a href="https://www.facebook.com/dynatrace" target="_blank"><img src="img/facebookbutton.png"/></a>
                            <a href="https://twitter.com/dynatrace" target="_blank"><img src="img/twitterbutton.png"/></a>
                            <a id="dynatrace" target="_blank" href="http://www.dynatrace.com"><img height="17px" width="17px" src="img/dynatrace.ico" /></a>
                            <img src="img/rssbutton.png"/>
                        </div>
                    </div>
                </div>
            </div>

            <div class="body_container">
                <div class="body_content">
                    <div class="contentContainer">
                        <div class="mainBox">
                            <h1 class="mainBoxHeader">새로운 특가 상품을 만나 보세요...</h1>
                            <div class="mainScrollBox">
                                <div class="mainTextBox">
                                	<script type="text/javascript">
										function specialOffersLoaded(){
											if(window.performance && window.performance.mark){
												window.performance.mark("mark_special_offers_loaded");
											}
										}
									</script>
                                    <p><img height="360px" src="img/specialoffersbig.png" width="500px" onload="specialOffersLoaded()" /></p>
									
                                </div>
                            </div>
                        </div>

                        <div class="orangeBanner">
                            <img src="img/easyTravel_banner.png" alt="promotion"/>
                        </div>
                        <div class="clearer"/>
                    </div>
                </div>
            </div>

            <div id="recommendation">
                <%= specialOffersBean.printRecommendations() %>
            </div>

            <div class="footer_container" xmlns="http://www.w3.org/1999/xhtml" xmlns:fb="http://www.facebook.com/2008/fbml" xmlns:og="http://ogp.me/ns#">
                <div style="width:100%;clear:both">&#160;</div>
                <div class="footer_content">
                    <div style="clear: both;"></div>
                    <span class="pluginFooter"></span>
                    <div style="clear: both;"></div>
                    <div class="orangeLegal">
                        운임 약관: www.easytravel.com에 게시된 왕복 및 편도 예시 운임은 1인 기준이며, 관련 세금과 수수료가 모두 포함되어 있습니다. 여기에는 미국 공항 출발 구간당 최대 $500의 9·11 보안 수수료, 여정에 따라 최대 $18의 공항시설 이용료, 구간당 $3.70의 연방 구간 수수료, 경로와 목적지에 따라 국제선 왕복 1회당 최대 $400의 해외 및 미국 정부 부과금이 포함되며 이에 한정되지 않습니다. 비행 구간은 1회 이륙과 1회 착륙을 의미합니다. 운임은 좌석 상황에 따라 달라질 수 있으며 사전 고지 없이 변경될 수 있습니다. 선택한 날짜에 광고된 운임을 이용할 수 없는 경우 더 높은 운임이 제시될 수 있습니다. 실제 가격은 실제 경로, 환율 변동(국제선에 한함), 요일에 따라 달라질 수 있습니다.
                    </div>
                    <div style="clear: both;"></div>
                    <div class="orangeFooter">
                    </div>
                </div>
            </div>
        </div>
    </body>
</html>
