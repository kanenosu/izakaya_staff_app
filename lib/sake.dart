import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'widgets/custom_bottom_nav_bar.dart';

class SakePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('日本酒一覧'), centerTitle: true),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // すでに日本酒ページなので何もしない
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/inventory');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/menu');
              break;
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        tooltip: '日本酒を追加',
        onPressed: () async {
          final nameController = TextEditingController();
          final tagController = TextEditingController();
          final imageUrlController = TextEditingController();
          final videoUrlController = TextEditingController();
          final priceController = TextEditingController();
          await showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('日本酒を追加'),
                  content: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: '銘柄名'),
                        ),
                        TextField(
                          controller: tagController,
                          decoration: const InputDecoration(
                            labelText: 'タグ（例: 辛口, 純米）',
                          ),
                        ),
                        TextField(
                          controller: priceController,
                          decoration: const InputDecoration(labelText: '値段'),
                          keyboardType: TextInputType.number,
                        ),
                        TextField(
                          controller: imageUrlController,
                          decoration: const InputDecoration(labelText: '画像URL'),
                        ),
                        TextField(
                          controller: videoUrlController,
                          decoration: const InputDecoration(
                            labelText: '紹介動画URL',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('キャンセル'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('sake')
                              .add({
                                'name': nameController.text,
                                'tags':
                                    tagController.text
                                        .split(',')
                                        .map((e) => e.trim())
                                        .toList(),
                                'imageUrl': imageUrlController.text,
                                'videoUrl': videoUrlController.text,
                                'price':
                                    int.tryParse(priceController.text) ?? 0,
                              });
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('追加'),
                    ),
                  ],
                ),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('sake').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('日本酒が登録されていません'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: docs.length,
            itemBuilder: (context, idx) {
              final data = docs[idx].data();
              final docId = docs[idx].id;
              final name = data['name'] ?? '';
              final tags = (data['tags'] as List?)?.cast<String>() ?? [];
              final imageUrl = data['imageUrl'] ?? '';
              final videoUrl = data['videoUrl'] ?? '';
              final price = data['price'] ?? 0;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => SakeDetailPage(
                            docId: docId,
                            name: name,
                            tags: tags,
                            imageUrl: imageUrl,
                            videoUrl: videoUrl,
                            price: price,
                          ),
                    ),
                  );
                },
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child:
                            imageUrl.isNotEmpty
                                ? ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (c, e, s) => const Icon(
                                          Icons.broken_image,
                                          size: 60,
                                        ),
                                  ),
                                )
                                : const Icon(
                                  Icons.local_drink,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2,
                        ),
                        child: Wrap(
                          spacing: 4,
                          children:
                              tags
                                  .map(
                                    (tag) => Chip(
                                      label: Text(
                                        tag,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: Colors.blue.shade50,
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          '￥${price.toString()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SakeDetailPage extends StatefulWidget {
  final String docId;
  final String name;
  final List<String> tags;
  final String imageUrl;
  final String videoUrl;
  final int price;

  const SakeDetailPage({
    required this.docId,
    required this.name,
    required this.tags,
    required this.imageUrl,
    required this.videoUrl,
    required this.price,
    Key? key,
  }) : super(key: key);

  @override
  State<SakeDetailPage> createState() => _SakeDetailPageState();
}

class _SakeDetailPageState extends State<SakeDetailPage> {
  late TextEditingController nameController;
  late TextEditingController tagController;
  late TextEditingController imageUrlController;
  late TextEditingController videoUrlController;
  late TextEditingController priceController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.name);
    tagController = TextEditingController(text: widget.tags.join(', '));
    imageUrlController = TextEditingController(text: widget.imageUrl);
    videoUrlController = TextEditingController(text: widget.videoUrl);
    priceController = TextEditingController(text: widget.price.toString());
  }

  @override
  void dispose() {
    nameController.dispose();
    tagController.dispose();
    imageUrlController.dispose();
    videoUrlController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance
        .collection('sake')
        .doc(widget.docId)
        .update({
          'name': nameController.text,
          'tags': tagController.text.split(',').map((e) => e.trim()).toList(),
          'imageUrl': imageUrlController.text,
          'videoUrl': videoUrlController.text,
          'price': int.tryParse(priceController.text) ?? 0,
        });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日本酒詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            imageUrlController.text.isNotEmpty
                ? Image.network(
                  imageUrlController.text,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (c, e, s) => const Icon(Icons.broken_image, size: 80),
                )
                : const Icon(Icons.local_drink, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '銘柄名'),
            ),
            TextField(
              controller: tagController,
              decoration: const InputDecoration(labelText: 'タグ（カンマ区切り）'),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: '値段'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: imageUrlController,
              decoration: const InputDecoration(labelText: '画像URL'),
            ),
            TextField(
              controller: videoUrlController,
              decoration: const InputDecoration(labelText: '紹介動画URL'),
            ),
            const SizedBox(height: 16),
            if (videoUrlController.text.isNotEmpty)
              SizedBox(
                height: 200,
                child: SakeVideoPlayer(videoUrl: videoUrlController.text),
              ),
          ],
        ),
      ),
    );
  }
}

class SakeVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const SakeVideoPlayer({required this.videoUrl, Key? key}) : super(key: key);

  @override
  State<SakeVideoPlayer> createState() => _SakeVideoPlayerState();
}

class _SakeVideoPlayerState extends State<SakeVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
          _controller.play();
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
