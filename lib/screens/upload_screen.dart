import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';
import '../models/post.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _image;
  final _captionCtrl = TextEditingController();
  bool _loading = false;
  final _picker = ImagePicker();
  final _storage = StorageService();
  final _firestore = FirestoreService();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _upload() async {
    if (_image == null) return;
    setState(() => _loading = true);

    try {
      final postId = const Uuid().v4();
      final user = context.read<UserProvider>().user;
      if (user == null) throw Exception('Usuario no autenticado');

      print('🔄 Subiendo imagen...');
      final imageUrl = await _storage.uploadPostImage(_image!, postId);
      print('✅ Imagen subida: $imageUrl');

      final post = PostModel(
        id:        postId,
        authorId:  user.uid,
        imageUrl:  imageUrl,
        caption:   _captionCtrl.text.trim(),
        timestamp: DateTime.now(),  // será sobreescrito por serverTimestamp
      );

      print('🔄 Guardando post en Firestore...');
      await _firestore.createPost(post);
      print('✅ Post creado con ID: $postId');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post subido con éxito')),
      );
      setState(() {
        _image = null;
        _captionCtrl.clear();
      });
    } catch (e, st) {
      print('❌ Error al subir post: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir post: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _image == null
              ? GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 200,
              color: Colors.grey[200],
              child: const Center(child: Text('Toca para seleccionar imagen')),
            ),
          )
              : Image.file(_image!, height: 200, fit: BoxFit.cover),
          const SizedBox(height: 12),
          TextField(
            controller: _captionCtrl,
            decoration: const InputDecoration(labelText: 'Caption'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _upload,
            child: _loading
                ? const SizedBox(
              height: 20, width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Text('Subir'),
          ),
        ],
      ),
    );
  }
}

