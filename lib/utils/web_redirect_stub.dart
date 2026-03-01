/// 비웹 플랫폼용 스텁 - 모바일에서는 사용되지 않음
void redirectToUrl(String url) {
  throw UnsupportedError('웹 리다이렉트는 웹 플랫폼에서만 사용 가능합니다.');
}

/// 비웹 플랫폼용 스텁
void clearUrlQueryParams() {}
