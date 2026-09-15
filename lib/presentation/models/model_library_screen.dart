import 'package:flutter/material.dart';

import 'widgets/huggingface_search_tab.dart';
import 'widgets/installed_models_tab.dart';

class ModelLibraryScreen extends StatelessWidget {
  const ModelLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Models'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Installed'),
              Tab(text: 'HuggingFace'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            InstalledModelsTab(),
            HuggingFaceSearchTab(),
          ],
        ),
      ),
    );
  }
}
