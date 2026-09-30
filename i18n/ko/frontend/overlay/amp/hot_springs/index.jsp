<%@ taglib prefix="c" uri="http://java.sun.com/jstl/core" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>

<%-- Eliminate the automatic creation of an HTTP session when accessing to a JSP page --%>
<%@page session="false"%>

<jsp:useBean id="ampWebsiteBean" class="com.dynatrace.easytravel.frontend.beans.AmpWebsiteBean" scope="request"/>
<!doctype html>
<html amp lang="en">
<head>
	<meta charset="utf-8">
	<script async src="https://cdn.ampproject.org/v0.js"></script>
	<title>easyTravel AMP 웹사이트</title>
	<link href="/amp/img/favicon_orange_plane.ico" rel="shortcut icon">
	<link rel="canonical" href="/amp/">
	<meta name="viewport" content="width=device-width,minimum-scale=1,initial-scale=1">
	<script async custom-element="amp-analytics" src="https://cdn.ampproject.org/v0/amp-analytics-0.1.js"></script>
	<script async custom-element="amp-sidebar" src="https://cdn.ampproject.org/v0/amp-sidebar-0.1.js"></script>
	<script async custom-element="amp-fit-text" src="https://cdn.ampproject.org/v0/amp-fit-text-0.1.js"></script>
	<script async custom-element="amp-social-share" src="https://cdn.ampproject.org/v0/amp-social-share-0.1.js"></script>
	<script async custom-element="amp-carousel" src="https://cdn.ampproject.org/v0/amp-carousel-0.1.js"></script>
	<style amp-custom>
		#header ul {
			list-style-type: none;
			margin: 0;
			padding: 0;
			overflow: hidden;
			background-color: #F7BE81;
		}

		#header li {
			float: left;
			height: 50px;
			border-right:1px solid #FBF5EF;
		}

		#header li:last-child {
			border-right: none;
			float: right;
		}

		#header li a {
			display: block;
			color: white;
			text-align: center;
			padding: 16px 16px;
			text-decoration: none;
		}

		#header .active {
			background-color: #FF8000;
		}

		#sidebar {
			background-color: #F7BE81;
			text-align: left;
		}

		#sidebar ul {
			list-style-type: none;
			margin: 0;
			padding: 10px;
		}

		#sidebar li {
			font: 200 20px/1.5 Helvetica, Verdana, sans-serif;
			border-bottom: 1px solid #FBF5EF;
		}

		#sidebar li:last-child {
			border: none;
		}

		#sidebar li a {
			text-decoration: none;
			color: #000;
			display: block;
			width: 200px;
		}

		#sidebar .navigation {
			font: 200 30px/1.5 Helvetica, Verdana, sans-serif;
		}

		#sidebar .dynatrace {
			text-align: center;
		}

		#content h1 {
			font-size: 80px;
			text-align: center;
			font-family: helvetica, sans-serif;
			text-transform: uppercase;
		}

		#content h3 {
			font-size: 30px;
			text-align: center;
			font-family: helvetica, sans-serif;
			text-transform: uppercase;
		}

		#content .articles {
			background-color: #f5f5f5;
			margin: 1rem;
			display: flex;
			color: #111;
			padding: 0;
			box-shadow: 0 1px 1px 0 rgba(0,0,0,.14), 0 1px 1px -1px rgba(0,0,0,.14), 0 1px 5px 0 rgba(0,0,0,.12);
			text-decoration: none;
		}

		#content .articles > span {
			font-weight: 400;
			margin: 8px;
		}

		#content p {
			margin: 30px;
			text-align: justify;
		}

		#content ul {
			list-style-type: none;
			margin: 0;
			padding: 10px;
		}

		.dynatrace-ad {
			margin: 0 auto;
		}

		.dynatrace-ad-container {
			display: flex;
		}
	</style>
	<style amp-boilerplate>body{-webkit-animation:-amp-start 8s steps(1,end) 0s 1 normal both;-moz-animation:-amp-start 8s steps(1,end) 0s 1 normal both;-ms-animation:-amp-start 8s steps(1,end) 0s 1 normal both;animation:-amp-start 8s steps(1,end) 0s 1 normal both}@-webkit-keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}@-moz-keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}@-ms-keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}@-o-keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}@keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}</style><noscript><style amp-boilerplate>body{-webkit-animation:none;-moz-animation:none;-ms-animation:none;animation:none}</style></noscript>
</head>
<body>
	<amp-sidebar id="sidebar" layout="nodisplay" side="left">
		<amp-img class="amp-close-image" srcset="/amp/img/ic_close_black_1x_web_24dp.png 1x, /amp/img/ic_close_black_2x_web_24dp.png 2x" width="40" height="40" alt="사이드바 닫기" on="tap:sidebar.close" role="button" tabindex="0"></amp-img>
		<div id="sidebar">
			<ul>
				<li><a class="dynatrace" href="http://www.dynatrace.com"><amp-img width="180px" height="60px" src="/amp/img/dynatrace-logo.png"></amp-img></a></li>
				<li><a class="navigation" href="/amp/index.jsp">홈</a></li>
				<li><a class="navigation" href="/amp/gallery.jsp">갤러리</a></li>
				<li><a class="navigation" href="/amp/offices.jsp">문의</a></li>
				<li><a class="navigation" href="/amp/info.jsp">소개</a></li>
				<li><a href="/amp/hazel_hurst/">Hazel Hurst – Porta Westfalica</a></li>
				<li><a href="/amp/latrobe/">Latrobe</a></li>
				<li><a href="/amp/italy/">이탈리아</a></li>
				<li><a href="/amp/imbler/">Imbler – Mardela Springs</a></li>
				<li><a href="/amp/hot_springs/">Latrobe – California Hot Springs</a></li>
			</ul>
		</div>
	</amp-sidebar>

	<div id="header">
		<ul>
			<li><a on="tap:sidebar.toggle"><amp-img src="/amp/img/ic_menu_white_1x_web_24dp.png" width="24" height="24" alt="메뉴"></amp-img></a></li>
			<li><a class="active" href="/amp/index.jsp">홈</a></li>
			<li><a href="/amp/gallery.jsp">갤러리</a></li>
			<li><a href="/amp/offices.jsp">문의</a></li>
			<li><a href="/amp/info.jsp">소개</a></li>
		</ul>
	</div>

	<div id="content">
		<div class="heading">
			<p><small>작성자 demouser - 최종 수정: 2013년 7월 4일 목요일</small></p>
			<amp-social-share type="twitter" width="40" height="33"></amp-social-share>
			<amp-social-share type="facebook" width="40" height="33"></amp-social-share>
			<amp-social-share type="gplus" width="40" height="33"></amp-social-share>
			<amp-social-share type="email" width="40" height="33"></amp-social-share>
			<amp-social-share type="linkedin" width="40" height="33"></amp-social-share>
			<h1><amp-fit-text height="200" layout="fixed-height">Latrobe – California Hot Springs</amp-fit-text></h1>
			<p id="summary">캘리포니아의 수많은 온천 중 한 곳에 몸을 담그면, 모두가 이곳을 사랑하는 또 하나의 이유를 알게 될 것입니다. 주 곳곳에서 미네랄이 풍부한 천연 온천수가 솟아오르며, 이를 즐기기 좋은 최고의 장소들을 모아 보았습니다.</p>
			<amp-img src="/amp/img/hot_springs.jpg" width="1280" height="853" layout="responsive"></amp-img>

			<p>캘리포니아 핫스프링스 리조트는 캘리포니아 시에라네바다 산맥 중남부에 있습니다. Mountain Road 56을 따라 세쿼이아 국립기념물에 들어서면 곧 유서 깊은 리조트를 만나게 됩니다.</p>

			<div class="dynatrace-ad-container"><a class="dynatrace-ad" href="http://www.dynatrace.com"><amp-img width="600px" height="200px" src="/amp/img/dynatrace-ads/dynatrace-2.png"></amp-img></a></div>

			<p>해발 3,100~3,700피트에 자리한 캘리포니아 핫스프링스는 대부분 안개선보다 높고 설선보다 낮습니다. 가끔 계곡의 안개나 고지대 시에라의 눈을 만날 수 있지만 오래가지는 않습니다. 겨울은 대체로 온화하고 여름은 화창하고 아름답습니다. 개인 소유의 리조트와 캠핑카 공원은 세 방향이 자이언트 세쿼이아 국립기념물과 맞닿아 있습니다. 하이킹을 좋아한다면 동쪽 국립기념물 안의 ‘Trail of a Hundred Giants’를 비롯한 자연 탐방로를 걸어 보세요.</p>

			<amp-carousel width="1280" height="1000" layout="responsive" type="slides">
				<figure>
					<amp-img src="/amp/img/hot_springs_1.jpg" width="1280" height="857" layout="responsive"></amp-img>
					<figcaption>캘리포니아의 온천</figcaption>
				</figure>
				<figure>
					<amp-img src="/amp/img/hot_springs_2.jpg" width="1280" height="853" layout="responsive"></amp-img>
					<figcaption>캘리포니아의 온천</figcaption>
				</figure>
				<figure>
					<amp-img src="/amp/img/hot_springs_3.jpg" width="1280" height="853" layout="responsive"></amp-img>
					<figcaption>캘리포니아의 온천</figcaption>
				</figure>
				<figure>
					<amp-img src="/amp/img/hot_springs_4.jpg" width="1280" height="853" layout="responsive"></amp-img>
					<figcaption>캘리포니아의 온천</figcaption>
				</figure>
			</amp-carousel>
			
			<h3>관련 글</h3>
			<ul>
				<li><a class="articles" href="/amp/latrobe/"><amp-img width="100" height="70" src="/amp/img/latrobe.jpg"></amp-img><span>Latrobe</span></a></li>
				<li><a class="articles" href="/amp/imbler/"><amp-img width="100" height="70" src="/amp/img/imbler.jpg"></amp-img><span>Imbler – Mardela Springs</span></a></li>
			</ul>
		</div>
	</div>

	<div>
		<%= ampWebsiteBean.getJavaScriptTag() %>
	</div>
</body>
</html>