// 지역 선택을 위한 모델
class Region {
  final String code;
  final String name;
  final List<Region>? children;

  Region({required this.code, required this.name, this.children});
}

// 한국 지역 데이터
class RegionData {
  static final List<Region> regions = [
    Region(
      code: 'seoul',
      name: '서울특별시',
      children: [
        Region(code: 'seoul_gangnam', name: '강남구'),
        Region(code: 'seoul_gangdong', name: '강동구'),
        Region(code: 'seoul_gangbuk', name: '강북구'),
        Region(code: 'seoul_gangseo', name: '강서구'),
        Region(code: 'seoul_gwanak', name: '관악구'),
        Region(code: 'seoul_gwangjin', name: '광진구'),
        Region(code: 'seoul_guro', name: '구로구'),
        Region(code: 'seoul_geumcheon', name: '금천구'),
        Region(code: 'seoul_nowon', name: '노원구'),
        Region(code: 'seoul_dobong', name: '도봉구'),
        Region(code: 'seoul_dongdaemun', name: '동대문구'),
        Region(code: 'seoul_dongjak', name: '동작구'),
        Region(code: 'seoul_mapo', name: '마포구'),
        Region(code: 'seoul_seodaemun', name: '서대문구'),
        Region(code: 'seoul_seocho', name: '서초구'),
        Region(code: 'seoul_seongdong', name: '성동구'),
        Region(code: 'seoul_seongbuk', name: '성북구'),
        Region(code: 'seoul_songpa', name: '송파구'),
        Region(code: 'seoul_yangcheon', name: '양천구'),
        Region(code: 'seoul_yeongdeungpo', name: '영등포구'),
        Region(code: 'seoul_yongsan', name: '용산구'),
        Region(code: 'seoul_eunpyeong', name: '은평구'),
        Region(code: 'seoul_jongno', name: '종로구'),
        Region(code: 'seoul_jung', name: '중구'),
        Region(code: 'seoul_jungnang', name: '중랑구'),
      ],
    ),
    Region(
      code: 'busan',
      name: '부산광역시',
      children: [
        Region(code: 'busan_gangseo', name: '강서구'),
        Region(code: 'busan_geumjeong', name: '금정구'),
        Region(code: 'busan_gijang', name: '기장군'),
        Region(code: 'busan_nam', name: '남구'),
        Region(code: 'busan_dong', name: '동구'),
        Region(code: 'busan_dongnae', name: '동래구'),
        Region(code: 'busan_busanjin', name: '부산진구'),
        Region(code: 'busan_buk', name: '북구'),
        Region(code: 'busan_sasang', name: '사상구'),
        Region(code: 'busan_saha', name: '사하구'),
        Region(code: 'busan_seo', name: '서구'),
        Region(code: 'busan_suyeong', name: '수영구'),
        Region(code: 'busan_yeonje', name: '연제구'),
        Region(code: 'busan_yeongdo', name: '영도구'),
        Region(code: 'busan_jung', name: '중구'),
        Region(code: 'busan_haeundae', name: '해운대구'),
      ],
    ),
    Region(
      code: 'incheon',
      name: '인천광역시',
      children: [
        Region(code: 'incheon_ganghwa', name: '강화군'),
        Region(code: 'incheon_gyeyang', name: '계양구'),
        Region(code: 'incheon_michuhol', name: '미추홀구'),
        Region(code: 'incheon_namdong', name: '남동구'),
        Region(code: 'incheon_dong', name: '동구'),
        Region(code: 'incheon_bupyeong', name: '부평구'),
        Region(code: 'incheon_seo', name: '서구'),
        Region(code: 'incheon_yeonsu', name: '연수구'),
        Region(code: 'incheon_ongjin', name: '옹진군'),
        Region(code: 'incheon_jung', name: '중구'),
      ],
    ),
    Region(
      code: 'daegu',
      name: '대구광역시',
      children: [
        Region(code: 'daegu_nam', name: '남구'),
        Region(code: 'daegu_dalseo', name: '달서구'),
        Region(code: 'daegu_dalseong', name: '달성군'),
        Region(code: 'daegu_dong', name: '동구'),
        Region(code: 'daegu_buk', name: '북구'),
        Region(code: 'daegu_seo', name: '서구'),
        Region(code: 'daegu_suseong', name: '수성구'),
        Region(code: 'daegu_jung', name: '중구'),
      ],
    ),
    Region(
      code: 'gwangju',
      name: '광주광역시',
      children: [
        Region(code: 'gwangju_gwangsan', name: '광산구'),
        Region(code: 'gwangju_nam', name: '남구'),
        Region(code: 'gwangju_dong', name: '동구'),
        Region(code: 'gwangju_buk', name: '북구'),
        Region(code: 'gwangju_seo', name: '서구'),
      ],
    ),
    Region(
      code: 'daejeon',
      name: '대전광역시',
      children: [
        Region(code: 'daejeon_daedeok', name: '대덕구'),
        Region(code: 'daejeon_dong', name: '동구'),
        Region(code: 'daejeon_seo', name: '서구'),
        Region(code: 'daejeon_yuseong', name: '유성구'),
        Region(code: 'daejeon_jung', name: '중구'),
      ],
    ),
    Region(
      code: 'ulsan',
      name: '울산광역시',
      children: [
        Region(code: 'ulsan_nam', name: '남구'),
        Region(code: 'ulsan_dong', name: '동구'),
        Region(code: 'ulsan_buk', name: '북구'),
        Region(code: 'ulsan_ulju', name: '울주군'),
        Region(code: 'ulsan_jung', name: '중구'),
      ],
    ),
    Region(
      code: 'gyeonggi',
      name: '경기도',
      children: [
        Region(code: 'gyeonggi_suwon', name: '수원시'),
        Region(code: 'gyeonggi_goyang', name: '고양시'),
        Region(code: 'gyeonggi_yongin', name: '용인시'),
        Region(code: 'gyeonggi_seongnam', name: '성남시'),
        Region(code: 'gyeonggi_bucheon', name: '부천시'),
        Region(code: 'gyeonggi_ansan', name: '안산시'),
        Region(code: 'gyeonggi_anyang', name: '안양시'),
        Region(code: 'gyeonggi_namyangju', name: '남양주시'),
        Region(code: 'gyeonggi_hwaseong', name: '화성시'),
        Region(code: 'gyeonggi_pyeongtaek', name: '평택시'),
      ],
    ),
    Region(
      code: 'gangwon',
      name: '강원특별자치도',
      children: [
        Region(code: 'gangwon_chuncheon', name: '춘천시'),
        Region(code: 'gangwon_wonju', name: '원주시'),
        Region(code: 'gangwon_gangneung', name: '강릉시'),
        Region(code: 'gangwon_donghae', name: '동해시'),
        Region(code: 'gangwon_taebaek', name: '태백시'),
        Region(code: 'gangwon_sokcho', name: '속초시'),
        Region(code: 'gangwon_samcheok', name: '삼척시'),
      ],
    ),
    Region(
      code: 'chungbuk',
      name: '충청북도',
      children: [
        Region(code: 'chungbuk_cheongju', name: '청주시'),
        Region(code: 'chungbuk_chungju', name: '충주시'),
        Region(code: 'chungbuk_jecheon', name: '제천시'),
      ],
    ),
    Region(
      code: 'chungnam',
      name: '충청남도',
      children: [
        Region(code: 'chungnam_cheonan', name: '천안시'),
        Region(code: 'chungnam_gongju', name: '공주시'),
        Region(code: 'chungnam_boryeong', name: '보령시'),
        Region(code: 'chungnam_asan', name: '아산시'),
        Region(code: 'chungnam_seosan', name: '서산시'),
      ],
    ),
    Region(
      code: 'jeonbuk',
      name: '전북특별자치도',
      children: [
        Region(code: 'jeonbuk_jeonju', name: '전주시'),
        Region(code: 'jeonbuk_gunsan', name: '군산시'),
        Region(code: 'jeonbuk_iksan', name: '익산시'),
        Region(code: 'jeonbuk_jeongeup', name: '정읍시'),
        Region(code: 'jeonbuk_namwon', name: '남원시'),
      ],
    ),
    Region(
      code: 'jeonnam',
      name: '전라남도',
      children: [
        Region(code: 'jeonnam_mokpo', name: '목포시'),
        Region(code: 'jeonnam_yeosu', name: '여수시'),
        Region(code: 'jeonnam_suncheon', name: '순천시'),
        Region(code: 'jeonnam_naju', name: '나주시'),
        Region(code: 'jeonnam_gwangyang', name: '광양시'),
      ],
    ),
    Region(
      code: 'gyeongbuk',
      name: '경상북도',
      children: [
        Region(code: 'gyeongbuk_pohang', name: '포항시'),
        Region(code: 'gyeongbuk_gyeongju', name: '경주시'),
        Region(code: 'gyeongbuk_kimcheon', name: '김천시'),
        Region(code: 'gyeongbuk_andong', name: '안동시'),
        Region(code: 'gyeongbuk_gumi', name: '구미시'),
        Region(code: 'gyeongbuk_yeongju', name: '영주시'),
      ],
    ),
    Region(
      code: 'gyeongnam',
      name: '경상남도',
      children: [
        Region(code: 'gyeongnam_changwon', name: '창원시'),
        Region(code: 'gyeongnam_jinju', name: '진주시'),
        Region(code: 'gyeongnam_tongyeong', name: '통영시'),
        Region(code: 'gyeongnam_sacheon', name: '사천시'),
        Region(code: 'gyeongnam_gimhae', name: '김해시'),
        Region(code: 'gyeongnam_miryang', name: '밀양시'),
        Region(code: 'gyeongnam_geoje', name: '거제시'),
      ],
    ),
    Region(
      code: 'jeju',
      name: '제주특별자치도',
      children: [
        Region(code: 'jeju_jeju', name: '제주시'),
        Region(code: 'jeju_seogwipo', name: '서귀포시'),
      ],
    ),
  ];
}
