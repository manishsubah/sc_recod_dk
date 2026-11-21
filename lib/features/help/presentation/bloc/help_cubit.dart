import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:reclite/core/constants/app_info.dart';
import 'package:reclite/core/errors/failures.dart';
import 'package:reclite/features/help/domain/repositories/links_repository.dart';

part 'help_state.dart';

class HelpCubit extends Cubit<HelpState> {
  HelpCubit(this._links) : super(const HelpState());

  final LinksRepository _links;

  /// "RecLite 0.1.0 (build 1) · Windows 10.0.26200", for support requests.
  String get versionDetails =>
      '${AppInfo.name} ${AppInfo.version} (build ${AppInfo.build}) · '
      '${_links.systemDescription}';

  Future<void> emailSupport() => _open(
    Uri(
      scheme: 'mailto',
      path: AppInfo.supportEmail,
      query: _query({
        'subject': '${AppInfo.name} help',
        'body': '\n\n---\n$versionDetails',
      }),
    ),
  );

  Future<void> openWebsite() => _open(Uri.parse(AppInfo.website));

  Future<void> _open(Uri link) async {
    try {
      await _links.open(link);
    } on Failure catch (e) {
      emit(HelpState(error: e.message));
      emit(const HelpState());
    }
  }

  // Uri's queryParameters encodes spaces as "+", which mail apps show literally.
  static String _query(Map<String, String> values) => values.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
}
