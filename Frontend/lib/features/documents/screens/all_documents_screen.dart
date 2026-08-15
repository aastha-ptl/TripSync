import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AllDocumentsScreen extends StatefulWidget {
  final String? title;
  final List<Map<String, dynamic>>? documents;

  const AllDocumentsScreen({super.key, this.title, this.documents});

  @override
  State<AllDocumentsScreen> createState() => _AllDocumentsScreenState();
}

class _AllDocumentsScreenState extends State<AllDocumentsScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  late final List<Map<String, dynamic>> _allDocs;

  @override
  void initState() {
    super.initState();
    _allDocs = widget.documents != null 
        ? List<Map<String, dynamic>>.from(widget.documents!)
        : [
            {
              'name': 'Aadhaar Card',
              'number': 'XXXX XXXX 4821',
              'category': 'Personal',
              'format': 'PDF',
              'size': '1.2 MB',
              'date': '10 Aug 2026',
              'icon': Icons.badge_outlined,
              'color': const Color(0xFF0284C7),
            },
            {
              'name': 'PAN Card',
              'number': 'XXXXX1234X',
              'category': 'Personal',
              'format': 'PNG',
              'size': '850 KB',
              'date': '09 Aug 2026',
              'icon': Icons.badge_outlined,
              'color': const Color(0xFF0D9488),
            },
            {
              'name': 'Passport',
              'number': 'ZXXXX1234',
              'category': 'Personal',
              'format': 'PDF',
              'size': '2.4 MB',
              'date': '08 Aug 2026',
              'icon': Icons.menu_book_outlined,
              'color': const Color(0xFF4F46E5),
            },
          ];
  }

  List<Map<String, dynamic>> get _filteredDocs {
    return _allDocs.where((doc) {
      final matchesSearch = doc['name']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          doc['number']!.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();
  }

  void _showDocumentDetails(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: doc['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(doc['icon'], color: doc['color'], size: 24),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  doc['name'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  doc['number'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                _buildDetailRow('Category', doc['category']),
                _buildDetailRow('Format', doc['format']),
                _buildDetailRow('File Size', doc['size']),
                _buildDetailRow('Uploaded On', doc['date']),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download_outlined, size: 18, color: Colors.white),
                        label: const Text('Download', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _simulateUpload() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selecting document...'), duration: Duration(milliseconds: 500)),
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() {
        _allDocs.insert(0, {
          'name': 'New Uploaded Doc',
          'number': 'ID: UPL-${DateTime.now().millisecond}',
          'category': 'Personal',
          'format': 'PDF',
          'size': '1.5 MB',
          'date': 'Today',
          'icon': Icons.description_outlined,
          'color': AppColors.primary,
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document uploaded successfully!'),
          backgroundColor: AppColors.secondary,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDocs;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1.0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title ?? 'My Documents',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_allDocs.length} items available',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _simulateUpload,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search documents...',
                      hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Documents grid
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.folder_open_outlined, size: 48, color: AppColors.textLight),
                        SizedBox(height: 12),
                        Text(
                          'No documents found',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      return GestureDetector(
                        onTap: () => _showDocumentDetails(doc),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: doc['color'].withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(doc['icon'], color: doc['color'], size: 18),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      doc['format'],
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc['name'],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    doc['number'],
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    doc['size'],
                                    style: const TextStyle(fontSize: 9, color: AppColors.textLight),
                                  ),
                                  Text(
                                    doc['date'],
                                    style: const TextStyle(fontSize: 9, color: AppColors.textLight),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
