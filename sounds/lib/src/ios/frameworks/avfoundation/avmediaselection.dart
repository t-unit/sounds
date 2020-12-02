// // Generated by @dartnative/codegen:
// // https://www.npmjs.com/package/@dartnative/codegen

// import 'dart:ffi';

// import 'package:dart_native/dart_native.dart';
// import 'package:dart_native_gen/dart_native_gen.dart';
// // You can uncomment this line when this package is ready.
// // import 'package:avfoundation/avbase.dart';
// // You can uncomment this line when this package is ready.
// // import 'package:foundation/foundation.dart';
// // You can uncomment this line when this package is ready.
// // import 'package:avfoundation/avasset.dart';
// // You can uncomment this line when this package is ready.
// // import 'package:avfoundation/avmediaselectiongroup.dart';

// @NativeAvailable(macos: '10.11', ios: '9.0', tvos: '9.0', watchos: '2.0')
// @native
// class AVMediaSelection extends NSObject with NSCopying, NSMutableCopying {
//   AVMediaSelection([Class isa]) : super(isa ?? Class('AVMediaSelection'));
//   AVMediaSelection.fromPointer(Pointer<Void> ptr) : super.fromPointer(ptr);

//   AVAsset get asset {
//     Pointer<Void> result = perform(SEL('asset'), decodeRetVal: false);
//     return AVAsset.fromPointer(result);
//   }

//   set asset(AVAsset asset) => perform(SEL('setAsset:'), args: [asset]);

//   AVMediaSelectionOption selectedMediaOptionInMediaSelectionGroup(
//       AVMediaSelectionGroup mediaSelectionGroup) {
//     Pointer<Void> result = perform(
//         SEL('selectedMediaOptionInMediaSelectionGroup:'),
//         args: [mediaSelectionGroup],
//         decodeRetVal: false);
//     return AVMediaSelectionOption.fromPointer(result);
//   }

//   bool mediaSelectionCriteriaCanBeAppliedAutomaticallyToMediaSelectionGroup(
//       AVMediaSelectionGroup mediaSelectionGroup) {
//     return perform(
//         SEL('mediaSelectionCriteriaCanBeAppliedAutomaticallyToMediaSelectionGroup:'),
//         args: [mediaSelectionGroup]);
//   }
// }

// @NativeAvailable(macos: '10.11', ios: '9.0', tvos: '9.0', watchos: '2.0')
// @native
// class AVMutableMediaSelection extends AVMediaSelection {
//   AVMutableMediaSelection([Class isa])
//       : super(isa ?? Class('AVMutableMediaSelection'));
//   AVMutableMediaSelection.fromPointer(Pointer<Void> ptr)
//       : super.fromPointer(ptr);

//   void selectMediaOptionInMediaSelectionGroup(
//       AVMediaSelectionGroup mediaSelectionGroup,
//       {AVMediaSelectionOption mediaSelectionOption}) {
//     perform(SEL('selectMediaOption:inMediaSelectionGroup:'),
//         args: [mediaSelectionOption, mediaSelectionGroup]);
//   }
// }
// // You can uncomment this line when this package is ready.
// // import 'package:avfcore/avmediaselection.dart';