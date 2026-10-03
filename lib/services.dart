import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'store.dart';

class LocResult {
  final Position? position;
  final String? error;
  final bool serviceOff;
  final bool deniedForever;
  const LocResult({this.position, this.error, this.serviceOff = false, this.deniedForever = false});
}

/// Real device GPS through the geolocator plugin.
class LocationService {
  static Position? last;

  static Future<LocResult> get() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocResult(error: 'GPS is turned off. Turn on Location to continue.', serviceOff: true);
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return const LocResult(error: 'Location permission was denied.');
      }
      if (perm == LocationPermission.deniedForever) {
        return const LocResult(
            error: 'Location permission is blocked. Allow it in app settings.', deniedForever: true);
      }
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (_) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown == null) rethrow;
        pos = lastKnown;
      }
      last = pos;
      store.anchorDemo(pos.latitude, pos.longitude);
      return LocResult(position: pos);
    } catch (e) {
      return LocResult(error: 'Could not read GPS location. Move to open sky and retry. ($e)');
    }
  }

  static Future<void> openSettings(LocResult r) async {
    if (r.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  /// Reverse-geocodes coordinates into a readable address (needs internet).
  static Future<String> address(double lat, double lng) async {
    try {
      final list = await placemarkFromCoordinates(lat, lng);
      if (list.isEmpty) return '';
      final p = list.first;
      final parts = <String?>[p.street, p.subLocality, p.locality, p.postalCode]
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      return parts.join(', ');
    } catch (_) {
      return '';
    }
  }
}

/// Lets the user take a photo or choose one, then copies it into the app's
/// private storage so it survives on the phone. Returns the saved file path.
Future<String?> pickPhoto(BuildContext context) async {
  final src = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (src == null) return null;
  try {
    final x = await ImagePicker().pickImage(source: src, imageQuality: 70, maxWidth: 1600);
    if (x == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${dir.path}/citypulse_images');
    if (!await imgDir.exists()) await imgDir.create(recursive: true);
    final path = '${imgDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(x.path).copy(path);
    return path;
  } catch (e) {
    if (context.mounted) showSnack(context, 'Could not add the photo: $e');
    return null;
  }
}

void showSnack(BuildContext context, String msg, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), action: action, behavior: SnackBarBehavior.floating));
}

Future<String?> askText(
  BuildContext context, {
  required String title,
  required String hint,
  String action = 'Submit',
  bool required = true,
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final t = ctrl.text.trim();
            if (required && t.isEmpty) return;
            Navigator.pop(ctx, t);
          },
          child: Text(action),
        ),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String message, {String yes = 'Confirm', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return r == true;
}
