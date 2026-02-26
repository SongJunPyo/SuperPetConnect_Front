// 지역 선택을 위한 모델 (시/도 단위)
class Region {
  final String code;
  final String name;

  Region({required this.code, required this.name});
}

// 한국 시/도 데이터
class RegionData {
  static final List<Region> regions = [
    Region(code: 'seoul', name: '서울특별시'),
    Region(code: 'busan', name: '부산광역시'),
    Region(code: 'incheon', name: '인천광역시'),
    Region(code: 'daegu', name: '대구광역시'),
    Region(code: 'gwangju', name: '광주광역시'),
    Region(code: 'daejeon', name: '대전광역시'),
    Region(code: 'ulsan', name: '울산광역시'),
    Region(code: 'sejong', name: '세종특별자치시'),
    Region(code: 'gyeonggi', name: '경기도'),
    Region(code: 'gangwon', name: '강원특별자치도'),
    Region(code: 'chungbuk', name: '충청북도'),
    Region(code: 'chungnam', name: '충청남도'),
    Region(code: 'jeonbuk', name: '전북특별자치도'),
    Region(code: 'jeonnam', name: '전라남도'),
    Region(code: 'gyeongbuk', name: '경상북도'),
    Region(code: 'gyeongnam', name: '경상남도'),
    Region(code: 'jeju', name: '제주특별자치도'),
  ];
}
