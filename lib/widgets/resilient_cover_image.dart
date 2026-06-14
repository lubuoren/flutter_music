import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/platform/cover_image_provider.dart';

class ResilientCoverImage extends StatefulWidget {
  const ResilientCoverImage({
    super.key,
    required this.coverUrl,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final String? coverUrl;
  final Widget fallback;
  final BoxFit fit;

  @override
  State<ResilientCoverImage> createState() => _ResilientCoverImageState();
}

class _ResilientCoverImageState extends State<ResilientCoverImage> {
  late List<String> _candidates;
  var _candidateIndex = 0;
  var _advanceScheduled = false;

  @override
  void initState() {
    super.initState();
    _candidates = coverImageUrlCandidates(widget.coverUrl);
  }

  @override
  void didUpdateWidget(covariant ResilientCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
      _candidates = coverImageUrlCandidates(widget.coverUrl);
      _candidateIndex = 0;
      _advanceScheduled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty) {
      return widget.fallback;
    }

    final candidate = _candidates[_candidateIndex];
    if (_isRemoteImageUrl(candidate)) {
      return CachedNetworkImage(
        imageUrl: candidate,
        httpHeaders: coverImageHttpHeaders(candidate),
        fit: widget.fit,
        fadeInDuration: const Duration(milliseconds: 120),
        fadeOutDuration: const Duration(milliseconds: 120),
        useOldImageOnUrlChange: true,
        placeholder: (context, url) => widget.fallback,
        errorWidget: (context, url, error) {
          _tryNextCandidate();
          return widget.fallback;
        },
      );
    }

    final provider = coverImageProvider(candidate);
    if (provider == null) {
      _tryNextCandidate();
      return widget.fallback;
    }

    return Image(
      image: provider,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        _tryNextCandidate();
        return widget.fallback;
      },
    );
  }

  void _tryNextCandidate() {
    if (_advanceScheduled || _candidateIndex >= _candidates.length - 1) {
      return;
    }
    _advanceScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _candidateIndex += 1;
        _advanceScheduled = false;
      });
    });
  }
}

List<String> coverImageUrlCandidates(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return const [];
  }

  final seen = <String>{};
  final candidates = <String>[];

  void add(String candidate) {
    final normalized = candidate.trim();
    if (normalized.isEmpty || !seen.add(normalized)) {
      return;
    }
    candidates.add(normalized);
  }

  add(trimmed);
  if (trimmed.startsWith('//')) {
    add('https:$trimmed');
    add('http:$trimmed');
  }

  final uri = Uri.tryParse(
    trimmed.startsWith('//') ? 'https:$trimmed' : trimmed,
  );
  if (uri == null || !uri.host.endsWith('music.126.net')) {
    return candidates;
  }

  final httpsUri = uri.replace(scheme: 'https');
  final httpUri = uri.replace(scheme: 'http');
  add(httpsUri.toString());
  add(_withNeteaseSizeParam(httpsUri, '512y512'));
  add(httpUri.toString());
  add(_withNeteaseSizeParam(httpUri, '512y512'));

  return candidates;
}

String _withNeteaseSizeParam(Uri uri, String size) {
  final queryParameters = Map<String, String>.from(uri.queryParameters);
  queryParameters['param'] = size;
  return uri.replace(queryParameters: queryParameters).toString();
}

bool _isRemoteImageUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

Map<String, String>? coverImageHttpHeaders(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.host.endsWith('music.126.net')) {
    return null;
  }
  return const {
    'Referer': 'https://music.163.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/125.0 Safari/537.36',
  };
}
