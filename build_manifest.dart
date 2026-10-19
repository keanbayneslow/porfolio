// Scans web/photos/ and writes web/photos.json.
//
// For every image (jpg, jpeg, png, webp, avif, gif) it looks for a text file
// with the same name (.md or .txt) holding the title and the story/poem.
// Run it with:  dart run tool/build_manifest.dart
// (GitHub Actions runs it for you on every push.)

import 'dart:convert';
import 'dart:io';

const imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.avif', '.gif'};

void main() {
  final dir = Directory('web/photos');
  if (!dir.existsSync()) {
    stderr.writeln('No web/photos folder found. Run this from the project root.');
    exit(1);
  }

  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()));

  final photos = <Map<String, Object?>>[];
  final usedSlugs = <String>{};

  for (final file in files) {
    final name = _name(file);
    final dot = name.lastIndexOf('.');
    if (dot <= 0) continue;
    final ext = name.substring(dot).toLowerCase();
    if (!imageExts.contains(ext)) continue;
    final base = name.substring(0, dot);

    // Slug: drop the leading order number, keep it URL friendly and unique.
    var slug = base
        .replaceFirst(RegExp(r'^\d+[-_ ]*'), '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    var unique = slug;
    var n = 2;
    while (!usedSlugs.add(unique)) {
      unique = '$slug-${n++}';
    }

    // Story file: same name, .md or .txt.
    final meta = <String, String>{};
    var body = '';
    for (final storyExt in ['.md', '.txt']) {
      final storyFile = File('${dir.path}/$base$storyExt');
      if (!storyFile.existsSync()) continue;
      final raw = storyFile.readAsStringSync().replaceAll('\r\n', '\n');
      final sep = RegExp(r'^---\s*$', multiLine: true).firstMatch(raw);
      if (sep != null) {
        for (final line in raw.substring(0, sep.start).split('\n')) {
          final i = line.indexOf(':');
          if (i > 0) {
            meta[line.substring(0, i).trim().toLowerCase()] = line.substring(i + 1).trim();
          }
        }
        body = raw.substring(sep.end);
      } else {
        body = raw;
      }
      break;
    }

    final size = _imageSize(file.readAsBytesSync(), ext);

    photos.add({
      'slug': unique,
      'src': 'photos/${Uri.encodeComponent(name)}',
      'title': meta['title'] ?? _titleFrom(base),
      'place': meta['place'] ?? '',
      'text': body.trim(),
      'width': size?.$1,
      'height': size?.$2,
    });
  }

  File('web/photos.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(photos));
  stdout.writeln('Wrote web/photos.json with ${photos.length} photo(s).');
}

String _name(File f) => f.uri.pathSegments.last;

String _titleFrom(String base) {
  final words = base
      .replaceFirst(RegExp(r'^\d+[-_ ]*'), '')
      .split(RegExp(r'[-_ ]+'))
      .where((w) => w.isNotEmpty);
  final title = words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  return title.isEmpty ? 'Untitled' : title;
}

/// Reads pixel dimensions from PNG or JPEG headers so the grid can reserve
/// space before images load. Returns null for other formats; the page then
/// measures the image once it has loaded.
(int, int)? _imageSize(List<int> b, String ext) {
  int be16(int i) => (b[i] << 8) | b[i + 1];
  int be32(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

  if (ext == '.png' && b.length > 24) return (be32(16), be32(20));

  if ((ext == '.jpg' || ext == '.jpeg') && b.length > 4) {
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) {
        i++;
        continue;
      }
      final m = b[i + 1];
      if (m == 0xFF) {
        i++;
        continue;
      }
      if (m == 0xD8 || m == 0x01 || (m >= 0xD0 && m <= 0xD7)) {
        i += 2;
        continue;
      }
      final isFrame = m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC;
      if (isFrame) return (be16(i + 7), be16(i + 5));
      i += 2 + be16(i + 2);
    }
  }
  return null;
}
