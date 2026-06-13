import 'dart:io';

import 'package:flutter/material.dart';

class TrackTileData {
  const TrackTileData({
    required this.id,
    required this.title,
    required this.subtitle,
    this.duration,
    this.coverPath,
  });

  final String id;
  final String title;
  final String subtitle;
  final Duration? duration;
  final String? coverPath;
}

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.trailing,
    this.selected = false,
  });

  final TrackTileData track;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: selected ? colorScheme.secondaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundImage: track.coverPath == null
              ? null
              : FileImage(File(track.coverPath!)) as ImageProvider,
          child: track.coverPath == null
              ? const Icon(Icons.music_note_rounded)
              : null,
        ),
        title: Text(track.title),
        subtitle: Text(track.subtitle),
        trailing:
            trailing ??
            (track.duration == null
                ? null
                : Text(
                    _formatDuration(track.duration!),
                    style: Theme.of(context).textTheme.bodySmall,
                  )),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
