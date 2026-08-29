import 'dart:io';

import 'package:flutter_app/data/file_manager/file_manager_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sandbox;
  late FileManagerService service;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('file_manager_test_');
    service = FileManagerService();
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('copy creates a uniquely named file without changing its contents',
      () async {
    final source = File('${sandbox.path}/source.txt');
    await source.writeAsString('real file contents');
    final destination = await Directory('${sandbox.path}/destination').create();
    await File('${destination.path}/source.txt').writeAsString('existing');
    service.clipboard = FileClipboard(paths: [source.path], isCut: false);

    final result = await service.paste(destination.path);

    expect(result.completed, 1);
    expect(result.errors, isEmpty);
    expect(
      await File('${destination.path}/source (1).txt').readAsString(),
      'real file contents',
    );
    expect(service.clipboard, isNull);
  });

  test('copying a folder into itself is blocked and remains retryable',
      () async {
    final source = await Directory('${sandbox.path}/source').create();
    final child = await Directory('${source.path}/child').create();
    service.clipboard = FileClipboard(paths: [source.path], isCut: false);

    final result = await service.paste(child.path);

    expect(result.completed, 0);
    expect(result.hasErrors, isTrue);
    expect(result.errors.single, contains('cannot be pasted inside itself'));
    expect(service.clipboard?.paths, [source.path]);
  });

  test('folder names cannot escape the selected parent', () async {
    expect(
      () => service.createFolder(sandbox.path, '../outside'),
      throwsA(isA<FileSystemException>()),
    );
  });
}
