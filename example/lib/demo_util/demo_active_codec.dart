import 'package:sounds/sounds.dart';
import 'package:sounds_common/sounds_common.dart';

/// Factory used to track what codec is currently selected.
class ActiveMediaFormat {
  static final ActiveMediaFormat _self = ActiveMediaFormat._internal();

  MediaFormat mediaFormat = AACADTSMediaFormat();
  bool _encoderSupported = false;
  bool _decoderSupported = false;

  ///
  SoundRecorder recorderModule;

  /// Factory to access the active codec.
  factory ActiveMediaFormat() {
    return _self;
  }
  ActiveMediaFormat._internal();

  /// Set the active code for the the recording and player modules.
  void setMediaFormat({bool withUI, MediaFormat mediaFormat}) async {
    _encoderSupported = await mediaFormat.isNativeEncoder;
    _decoderSupported = await mediaFormat.isNativeDecoder;

    mediaFormat = mediaFormat;
  }

  /// [true] if the active coded is supported by the recorder
  bool get encoderSupported => _encoderSupported;

  /// [true] if the active coded is supported by the player
  bool get decoderSupported => _decoderSupported;
}
