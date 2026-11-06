import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/app_user.dart';
import '../../state/app_state.dart';
import '../theme/aura_colors.dart';

/// Foto profil pengguna; bila belum ada foto (atau belum termuat), huruf
/// pertama namanya di atas gradasi.
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.size = 50,
    this.radius = 16,
  });

  final AppUser? user;
  final double size;
  final double radius;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Future<ImageProvider?>? _image;
  String? _loadedPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  /// Memuat foto hanya bila letaknya berubah, bukan setiap kali dibangun.
  void _load() {
    final user = widget.user;
    final path = user?.avatarPath;
    if (path == _loadedPath && _image != null) return;
    _loadedPath = path;
    _image = user == null || path == null
        ? Future.value()
        : context.read<AppState>().avatarImage(user);
  }

  @override
  Widget build(BuildContext context) {
    final initial = Container(
      decoration: BoxDecoration(
        gradient: AuraColors.cool,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: Center(
        child: Text(
          (widget.user?.name ?? '?').characters.first.toUpperCase(),
          style: TextStyle(
            fontSize: widget.size * 0.42,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );

    return SizedBox.square(
      dimension: widget.size,
      child: FutureBuilder<ImageProvider?>(
        future: _image,
        builder: (context, snapshot) {
          final image = snapshot.data;
          if (image == null) return initial;
          return ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: Image(
              image: image,
              fit: BoxFit.cover,
              // Tanpa internet atau tautan kedaluwarsa: kembali ke inisial.
              errorBuilder: (_, _, _) => initial,
              frameBuilder: (context, child, frame, sync) =>
                  sync || frame != null ? child : initial,
            ),
          );
        },
      ),
    );
  }
}
