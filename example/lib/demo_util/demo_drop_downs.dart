import 'package:flutter/material.dart';
import 'package:sounds_common/sounds_common.dart';

import 'demo_active_codec.dart';
import 'demo_common.dart';
import 'demo_media_path.dart';

/// Widget containing the set of drop downs used in the UI
/// Media
/// Codec
class Dropdowns extends StatefulWidget {
  final void Function(MediaFormat) _onMediaFormatChanged;

  /// ctor
  const Dropdowns({
    Key key,
    @required void Function(MediaFormat) onMediaFormatChanged,
  })  : _onMediaFormatChanged = onMediaFormatChanged,
        super(key: key);

  @override
  _DropdownsState createState() => _DropdownsState();
}

class _DropdownsState extends State<Dropdowns> {
  _DropdownsState();

  @override
  Widget build(BuildContext context) {
    final mediaDropdown = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Text('Record To:'),
        ),
        buildMediaDropdown(),
      ],
    );

    final codecDropdown = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Text('Codec:'),
        ),
        buildCodecDropdown(),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          mediaDropdown,
          codecDropdown,
        ],
      ),
    );
  }

  DropdownButton<MediaFormat> buildCodecDropdown() {
    return DropdownButton<MediaFormat>(
      value: ActiveMediaFormat().mediaFormat,
      onChanged: (newMediaFormat) async {
        widget._onMediaFormatChanged(newMediaFormat);

        /// this is hacky as we should be passing the actual
        /// useOSUI flag.
        await ActiveMediaFormat()
            .setMediaFormat(withUI: false, mediaFormat: newMediaFormat);

        await getDuration(ActiveMediaFormat().mediaFormat);
        setState(() {});
      },
      items: <DropdownMenuItem<MediaFormat>>[
        DropdownMenuItem<MediaFormat>(
          value: WellKnownMediaFormats.aacAdts,
          child: Text(WellKnownMediaFormats.aacAdts.name),
        ),
        DropdownMenuItem<MediaFormat>(
          value: WellKnownMediaFormats.oggOpus,
          child: Text('OGG/Opus'),
        ),
        DropdownMenuItem<MediaFormat>(
          value: WellKnownMediaFormats.opusCaf,
          child: Text('CAF/Opus'),
        ),
        DropdownMenuItem<MediaFormat>(
          value: WellKnownMediaFormats.mp3,
          child: Text('MP3'),
        ),
        DropdownMenuItem<MediaFormat>(
          value: WellKnownMediaFormats.oggVorbis,
          child: Text('OGG/Vorbis'),
        ),
        DropdownMenuItem<MediaFormat>(
          value: WellKnownMediaFormats.pcm,
          child: Text('PCM'),
        ),
      ],
    );
  }

  DropdownButton<MediaStorage> buildMediaDropdown() {
    return DropdownButton<MediaStorage>(
      value: MediaPath().media,
      onChanged: (newMedia) {
        MediaPath().media = newMedia;

        setState(() {});
      },
      items: <DropdownMenuItem<MediaStorage>>[
        DropdownMenuItem<MediaStorage>(
          value: MediaStorage.file,
          child: Text('File'),
        ),
        DropdownMenuItem<MediaStorage>(
          value: MediaStorage.buffer,
          child: Text('Buffer'),
        ),
      ],
    );
  }
}
