import 'package:flutter/material.dart';

import 'tieba/feed_page.dart';

class TiebaTab extends StatelessWidget {
  const TiebaTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const TiebaFeedPage(external: false);
  }
}