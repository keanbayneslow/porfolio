// Portfolio front end. Compiled to JavaScript with `dart compile js`.
//
// Routes (hash based, so it works on GitHub Pages without server config):
//   #/            landing page
//   #/work        the photo index
//   #/work/<slug> a single photo with its story

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

// ---------------------------------------------------------------- data

class Photo {
  Photo({
    required this.slug,
    required this.src,
    required this.title,
    required this.place,
    required this.text,
    this.width,
    this.height,
  });

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
        slug: j['slug'] as String,
        src: j['src'] as String,
        title: (j['title'] ?? '') as String,
        place: (j['place'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
      );

  final String slug, src, title, place, text;
  final int? width, height;
}

class Site {
  const Site({this.name = 'PORTFOLIO', this.tagline = '', this.featured});
  final String name, tagline;
  final String? featured;
}

// ---------------------------------------------------------------- state

late final web.HTMLElement app;
List<Photo> photos = [];
Site site = const Site();

int? viewerIndex;
web.HTMLElement? _stage;
web.HTMLImageElement? _viewerImg;
web.HTMLElement? _storyMeta, _storyTitle, _storyText, _counter;

int _navToken = 0;
num _gridScroll = 0;
double? _touchX;

const _leaveMs = 420;
const _swapMs = 320;

// ---------------------------------------------------------------- boot

Future<void> main() async {
  app = web.document.querySelector('#app') as web.HTMLElement;

  try {
    final results = await Future.wait([_getJson('photos.json'), _getJson('site.json')]);
    final p = results[0];
    final s = results[1];
    if (p is List) {
      photos = p.map((e) => Photo.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (s is Map) {
      site = Site(
        name: (s['name'] ?? 'PORTFOLIO') as String,
        tagline: (s['tagline'] ?? '') as String,
        featured: s['featured'] as String?,
      );
    }
  } catch (e) {
    print('Could not load content: $e');
  }

  web.document.title = site.name;
  listen(web.window, 'hashchange', (_) => route());
  listen(web.document, 'keydown', (e) => _onKey(e as web.KeyboardEvent));
  route();
}

Future<Object?> _getJson(String url) async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final res = await web.window.fetch('$url?v=$stamp'.toJS).toDart;
  if (!res.ok) return null;
  final text = (await res.text().toDart).toDart;
  return jsonDecode(text);
}

// ---------------------------------------------------------------- routing

void go(String hash) => web.window.location.hash = hash;

void route() {
  final parts = web.window.location.hash
      .replaceFirst(RegExp(r'^#/?'), '')
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    viewerIndex = null;
    _show(_buildHome);
  } else if (parts.first == 'work' && parts.length == 1) {
    viewerIndex = null;
    _show(_buildGrid);
  } else if (parts.first == 'work') {
    final slug = Uri.decodeComponent(parts[1]);
    final i = photos.indexWhere((p) => p.slug == slug);
    if (i < 0) {
      go('#/work');
    } else if (viewerIndex != null && _stage != null) {
      _swapTo(i);
    } else {
      viewerIndex = i;
      _show(() => _buildViewer(i));
    }
  } else {
    go('#/');
  }
}

/// Fades the current view out, then builds and fades in the next one.
Future<void> _show(web.HTMLElement Function() build) async {
  final token = ++_navToken;
  final root = web.document.documentElement!;
  final old = app.firstElementChild;

  if (old != null) {
    if (old.classList.contains('grid-view')) _gridScroll = root.scrollTop;
    old.classList.add('out');
    await Future<void>.delayed(const Duration(milliseconds: _leaveMs));
    if (token != _navToken) return;
  }

  _stage = null;
  app.textContent = '';
  final view = build();
  app.appendChild(view);
  root.scrollTop = view.classList.contains('grid-view') ? _gridScroll : 0;
}

void _onKey(web.KeyboardEvent e) {
  if (viewerIndex == null) return;
  switch (e.key) {
    case 'ArrowRight':
      step(1);
    case 'ArrowLeft':
      step(-1);
    case 'Escape':
      go('#/work');
  }
}

void step(int delta) {
  if (photos.isEmpty || viewerIndex == null) return;
  final n = (viewerIndex! + delta + photos.length) % photos.length;
  go('#/work/${Uri.encodeComponent(photos[n].slug)}');
}

// ---------------------------------------------------------------- views

web.HTMLElement _buildHome() {
  final view = el('section', cls: 'view home');

  if (photos.isNotEmpty) {
    final featured = photos.firstWhere(
      (p) => p.slug == site.featured,
      orElse: () => photos.first,
    );
    view.appendChild(el('div', cls: 'home-bg', children: [img(featured.src, '')]));
  }

  // Each letter flickers on separately, like a sign warming up.
  final title = el('h1', cls: 'neon');
  title.setAttribute('aria-label', site.name);
  final letters = site.name.split('');
  for (var i = 0; i < letters.length; i++) {
    final span = el('span', text: letters[i]);
    span.setAttribute('aria-hidden', 'true');
    span.style.setProperty('--d', '${200 + ((i * 7919) % 11) * 90}ms');
    title.appendChild(span);
  }

  view.appendChild(el('div', cls: 'home-inner', children: [
    el('p', cls: 'kicker mono', text: '${_pad(photos.length)} frames'),
    title,
    if (site.tagline.isNotEmpty) el('p', cls: 'tagline', text: site.tagline),
    link('#/work', cls: 'enter mono', children: [
      el('span', text: 'Enter'),
      el('span', cls: 'arrow', text: '→'),
    ]),
  ]));

  view.appendChild(el('div', cls: 'corner tl mono', text: 'Photographs & words'));
  view.appendChild(el('div', cls: 'corner br mono', text: '© ${DateTime.now().year}'));
  return view;
}

web.HTMLElement _buildGrid() {
  final view = el('section', cls: 'view grid-view');
  view.appendChild(el('header', cls: 'bar', children: [
    link('#/', cls: 'brand', text: site.name),
    el('span', cls: 'mono dim', text: 'Index / ${_pad(photos.length)}'),
  ]));

  final grid = el('div', cls: 'grid');
  for (var i = 0; i < photos.length; i++) {
    final p = photos[i];
    final frame = el('div', cls: 'card-frame');
    if (p.width != null && p.height != null) {
      frame.style.setProperty('aspect-ratio', '${p.width} / ${p.height}');
    }
    final image = img(p.src, p.title, lazy: true);
    listen(image, 'load', (_) {
      frame.style.setProperty('aspect-ratio', '${image.naturalWidth} / ${image.naturalHeight}');
    });
    frame.appendChild(image);

    final card = link('#/work/${Uri.encodeComponent(p.slug)}', cls: 'card', children: [
      frame,
      el('div', cls: 'card-cap mono', children: [
        el('span', text: _pad(i + 1)),
        el('span', text: p.title),
      ]),
    ]);
    card.style.setProperty('--i', '${i % 12}');
    grid.appendChild(card);
  }
  if (photos.isEmpty) {
    grid.appendChild(el('p', cls: 'empty mono', text: 'No photos yet. Add some to web/photos.'));
  }
  view.appendChild(grid);
  return view;
}

web.HTMLElement _buildViewer(int index) {
  viewerIndex = index;
  final view = el('section', cls: 'view viewer');

  _counter = el('span', cls: 'counter mono');
  view.appendChild(el('header', cls: 'bar', children: [
    link('#/work', cls: 'back mono', children: [
      el('span', cls: 'arrow', text: '←'),
      el('span', text: 'Back'),
    ]),
    _counter!,
  ]));

  final image = web.HTMLImageElement()
    ..className = 'viewer-img'
    ..decoding = 'async';
  listen(image, 'load', (_) => _stage?.classList.remove('swapping'));
  _viewerImg = image;

  final frame = el('figure', cls: 'frame', children: [image]);
  listen(frame, 'touchstart', (e) {
    _touchX = (e as web.TouchEvent).changedTouches.item(0)?.clientX.toDouble();
  });
  listen(frame, 'touchend', (e) {
    final start = _touchX;
    final end = (e as web.TouchEvent).changedTouches.item(0)?.clientX.toDouble();
    _touchX = null;
    if (start == null || end == null) return;
    final dx = end - start;
    if (dx.abs() > 50) step(dx < 0 ? 1 : -1);
  });

  _storyMeta = el('p', cls: 'story-meta mono');
  _storyTitle = el('h2', cls: 'story-title');
  _storyText = el('div', cls: 'story-text');

  _stage = el('div', cls: 'stage swapping', children: [
    frame,
    el('article', cls: 'story', children: [_storyMeta!, _storyTitle!, _storyText!]),
  ]);
  view.appendChild(_stage!);

  if (photos.length > 1) {
    view.appendChild(el('nav', cls: 'pager mono', children: [
      button('← Prev', () => step(-1)),
      button('Next →', () => step(1)),
    ]));
  }

  _fill(index);
  return view;
}

/// Crossfades the viewer to another photo without rebuilding the page.
Future<void> _swapTo(int i) async {
  if (i == viewerIndex) return;
  final token = ++_navToken;
  viewerIndex = i;
  _stage!.classList.add('swapping');
  await Future<void>.delayed(const Duration(milliseconds: _swapMs));
  if (token != _navToken || _stage == null) return;
  _fill(i);
}

void _fill(int i) {
  final p = photos[i];
  final token = _navToken;

  _viewerImg!
    ..alt = p.title
    ..src = p.src;

  _storyMeta!.textContent = p.place;
  _storyTitle!.textContent = p.title;
  _storyText!.textContent = '';
  for (final para in p.text.split(RegExp(r'\n\s*\n'))) {
    if (para.trim().isEmpty) continue;
    _storyText!.appendChild(el('p', text: para.trim()));
  }
  _counter!.textContent = '${_pad(i + 1)} / ${_pad(photos.length)}';
  web.document.title = '${p.title} — ${site.name}';

  // Safety net in case the load event never fires (e.g. a broken image).
  Future<void>.delayed(const Duration(milliseconds: 1600), () {
    if (token == _navToken) _stage?.classList.remove('swapping');
  });

  // Warm the cache for the neighbours so next/prev feel instant.
  for (final d in [1, -1]) {
    if (photos.length < 2) break;
    web.HTMLImageElement().src = photos[(i + d + photos.length) % photos.length].src;
  }
}

// ---------------------------------------------------------------- helpers

void listen(web.EventTarget target, String type, void Function(web.Event) handler) {
  target.addEventListener(type, handler.toJS);
}

web.HTMLElement el(
  String tag, {
  String? cls,
  String? text,
  List<web.Node> children = const [],
}) {
  final e = web.document.createElement(tag) as web.HTMLElement;
  if (cls != null) e.className = cls;
  if (text != null) e.textContent = text;
  for (final c in children) {
    e.appendChild(c);
  }
  return e;
}

web.HTMLAnchorElement link(
  String href, {
  String? cls,
  String? text,
  List<web.Node> children = const [],
}) {
  final a = web.document.createElement('a') as web.HTMLAnchorElement;
  a.href = href;
  if (cls != null) a.className = cls;
  if (text != null) a.textContent = text;
  for (final c in children) {
    a.appendChild(c);
  }
  return a;
}

web.HTMLButtonElement button(String label, void Function() onTap) {
  final b = web.HTMLButtonElement()
    ..type = 'button'
    ..textContent = label;
  listen(b, 'click', (_) => onTap());
  return b;
}

web.HTMLImageElement img(String src, String alt, {bool lazy = false}) {
  final i = web.HTMLImageElement()
    ..alt = alt
    ..decoding = 'async';
  if (lazy) i.loading = 'lazy';
  listen(i, 'load', (_) => i.classList.add('loaded'));
  i.src = src;
  if (i.complete && i.naturalWidth > 0) i.classList.add('loaded');
  return i;
}

String _pad(int n) => n.toString().padLeft(2, '0');
