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
			<p><small>작성자 demouser - 최종 수정: 2013년 7월 5일 금요일</small></p>
			<amp-social-share type="twitter" width="40" height="33"></amp-social-share>
			<amp-social-share type="facebook" width="40" height="33"></amp-social-share>
			<amp-social-share type="gplus" width="40" height="33"></amp-social-share>
			<amp-social-share type="email" width="40" height="33"></amp-social-share>
			<amp-social-share type="linkedin" width="40" height="33"></amp-social-share>
			<h1><amp-fit-text height="200" layout="fixed-height">이탈리아</amp-fit-text></h1>
			<p id="summary">이탈리아는 1861년까지 여러 지역 국가로 나뉘어 있었기 때문에, 건축 양식을 시대만이 아니라 지역별로도 나눠 봐야 할 만큼 폭넓고 다양합니다. 그 결과 매우 다채롭고 절충적인 건축 디자인이 탄생했습니다.</p>
			<amp-img src="/amp/img/italy.jpg" width="1280" height="853" layout="responsive"></amp-img>

			<p>이탈리아는 고대 로마의 아치와 돔 건축, 14세기 말~16세기 르네상스 건축 운동의 시작, 그리고 신고전주의 건축에 영감을 주고 17세기 말~20세기 초 영국, 호주, 미국 등 전 세계 귀족 저택 디자인에 영향을 준 팔라디오 양식의 발상지로 유명합니다. 콜로세움, 밀라노 대성당과 피렌체 대성당, 피사의 사탑, 베네치아의 건축물 등 서양 건축의 걸작 상당수가 이탈리아에 있습니다.</p>

			<div class="dynatrace-ad-container"><a class="dynatrace-ad" href="http://www.dynatrace.com"><amp-img width="400px" height="250px" src="/amp/img/dynatrace-ads/dynatrace-4.jpg"></amp-img></a></div>

			<p>이탈리아 건축은 세계 건축에도 폭넓은 영향을 미쳤습니다. 영국 건축가 이니고 존스는 이탈리아의 건물과 도시, 특히 안드레아 팔라디오에게서 영감을 받아 17세기 영국에 이탈리아 르네상스 건축을 들여왔습니다. 또한 19세기부터 해외에서 유행한 ‘이탈리아네이트(Italianate)’ 양식은 르네상스 건축을 본떠 이탈리아풍으로 지은 외국 건축물을 가리킵니다.</p>

			<amp-carousel width="1280" height="1000" layout="responsive" type="slides">
				<figure>
					<amp-img src="/amp/img/italy_1.jpg" width="1280" height="857" layout="responsive"></amp-img>
					<figcaption>트레비 분수</figcaption>
				</figure>
				<figure>
					<amp-img src="/amp/img/italy_2.jpg" width="1280" height="853" layout="responsive"></amp-img>
					<figcaption>콜로세움</figcaption>
				</figure>
				<figure>
					<amp-img src="/amp/img/italy_3.jpg" width="1280" height="853" layout="responsive"></amp-img>
					<figcaption>로마 풍경</figcaption>
				</figure>
				<figure>
					<amp-img src="/amp/img/italy_4.jpg" width="1280" height="853" layout="responsive"></amp-img>
					<figcaption>콜로세움</figcaption>
				</figure>
				<figure>
					<amp-img src="/amp/img/italy_5.jpg" width="1280" height="853" layout="responsive"></amp-img>
					<figcaption>로마 야경</figcaption>
				</figure>
			</amp-carousel>
			
			<h3>관련 글</h3>
			<ul>
				<li><a class="articles" href="/amp/hazel_hurst/"><amp-img width="100" height="70" src="/amp/img/porta_westfalica.jpg"></amp-img><span>Hazel Hurst – Porta Westfalica</span></a></li>
				<li><a class="articles" href="/amp/latrobe/"><amp-img width="100" height="70" src="/amp/img/latrobe.jpg"></amp-img><span>Latrobe</span></a></li>
			</ul>
		</div>
	</div>

	<div>
		<%= ampWebsiteBean.getJavaScriptTag() %>
	</div>
</body>
</html>