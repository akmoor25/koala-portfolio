import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'notice_banner.dart';

/// このアプリがポートフォリオ専用であることの説明文。
///
/// 起動画面と「このアプリについて」で同じ文言を使う。文言は ARB（`portfolioNoticeTitle`、
/// `portfolioNoticeBody`）にある。見た目は [NoticeBanner]（注意）。
class PortfolioNotice extends StatelessWidget {
  /// 何も受け取らない。
  const PortfolioNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return NoticeBanner(
      kind: NoticeKind.warning,
      icon: Icons.info_outline,
      title: l10n.portfolioNoticeTitle,
      message: l10n.portfolioNoticeBody,
    );
  }
}
