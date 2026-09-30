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
			<p><small>작성자 demouser - 최종 수정: 2013년 7월 5일 금요일</small></p>
			<amp-social-share type="twitter" width="40" height="33"></amp-social-share>
			<amp-social-share type="facebook" width="40" height="33"></amp-social-share>
			<amp-social-share type="gplus" width="40" height="33"></amp-social-share>
			<amp-social-share type="email" width="40" height="33"></amp-social-share>
			<amp-social-share type="linkedin" width="40" height="33"></amp-social-share>
			<h1><amp-fit-text height="200" layout="fixed-height">Latrobe</amp-fit-text></h1>
			<p id="summary">라트로브(Latrobe, 옛 이름 La Trobe)는 캘리포니아주 엘도라도 카운티의 비법인 지역 공동체입니다. 플레이서빌에서 남서쪽으로 15마일(24km), 해발 761피트(232m)에 있습니다.</p>
			<amp-img src="/amp/img/latrobe.jpg" width="1280" height="853" layout="responsive"></amp-img>

			<p>라트로브는 플레이서빌-새크라멘토 철도의 종착역이었습니다. 이 이름은 철도 수석 기술자 F.A. Bishop이 미국 최초의 철도인 볼티모어-오하이오 철도의 수석 기술자 Benjamin Henry Latrobe II를 기리기 위해 붙였습니다. 1864년부터 1921년까지 라트로브에는 우체국이 있었습니다.</p>

			<div class="dynatrace-ad-container"><a class="dynatrace-ad" href="http://www.dynatrace.com"><amp-img width="400px" height="300px" src="/amp/img/dynatrace-ads/dynatrace-5.png"></amp-img></a></div>

			<h3>관련 글</h3>
			<ul>
				<li><a class="articles" href="/amp/italy/"><amp-img width="100" height="70" src="/amp/img/italy.jpg"></amp-img><span>이탈리아</span></a></li>
				<li><a class="articles" href="/amp/hot_springs/"><amp-img width="100" height="70" src="/amp/img/hot_springs.jpg"></amp-img><span>Latrobe – California Hot Springs</span></a></li>
			</ul>
		</div>
	</div>

		<div>
		<%= ampWebsiteBean.getJavaScriptTag() %>
	</div>
</body>
</html>