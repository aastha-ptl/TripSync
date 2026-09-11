import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/document_service.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_endpoints.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import '../../trip/services/trip_service.dart';
import '../../auth/services/auth_service.dart';
import '../../profile/services/user_service.dart';

class AllDocumentsScreen extends StatefulWidget {
  final String? title;
  final List<dynamic>? documents;
  final Map<String, dynamic>? tripData;
  final bool isFamilyLeader;
  final String? ownerId;
  final String? ownerName;

  const AllDocumentsScreen({
    super.key,
    this.title,
    this.documents,
    this.tripData,
    this.isFamilyLeader = false,
    this.ownerId,
    this.ownerName,
  });

  @override
  State<AllDocumentsScreen> createState() => _AllDocumentsScreenState();
}

class _AllDocumentsScreenState extends State<AllDocumentsScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<dynamic> _allDocs = [];
  bool _isUploading = false;
  final DocumentService _documentService = DocumentService();
  
  bool _isLoadingParticipants = false;
  List<Map<String, dynamic>> _participants = [];

  @override
  void initState() {
    super.initState();
    _allDocs = widget.documents != null 
        ? List<dynamic>.from(widget.documents!)
        : [];
        
    final titleLower = widget.title?.toLowerCase() ?? '';
    final isGroupedView = titleLower == 'member documents' || titleLower == 'family member documents';
    if (isGroupedView) {
      _fetchParticipants();
    }
  }

  Future<void> _fetchParticipants() async {
    if (widget.tripData == null || widget.tripData!['_id'] == null) return;
    setState(() => _isLoadingParticipants = true);
    try {
      final tripService = TripService();
      final userService = UserService();
      
      final profileRes = await userService.getProfile();
      final currentUserId = profileRes['success'] == true ? profileRes['data']['_id'] : null;

      final response = await tripService.getTripParticipants(widget.tripData!['_id']);
      if (response['success'] == true && mounted) {
        final List<Map<String, dynamic>> allParticipants = List<Map<String, dynamic>>.from(response['data']);
        List<Map<String, dynamic>> list = [];
        
        if (widget.isFamilyLeader && currentUserId != null) {
          final myFamily = allParticipants.firstWhere(
            (p) => p['type'] == 'Family' && p['userId'] == currentUserId,
            orElse: () => <String, dynamic>{},
          );
          if (myFamily.isNotEmpty && myFamily['familyMembers'] != null) {
            list = List<Map<String, dynamic>>.from(myFamily['familyMembers']);
          }
        } else {
          for (var p in allParticipants) {
            final user = p['userId'];
            if (user != null && user == currentUserId) continue;
            list.add(p);
            if (p['familyMembers'] != null && p['familyMembers'] is List) {
              for (var fm in p['familyMembers']) {
                if (fm is Map) {
                  list.add(Map<String, dynamic>.from(fm));
                }
              }
            }
          }
        }

        setState(() {
          _participants = list;
        });
      }
    } catch (e) {
      debugPrint('Error fetching participants: $e');
    } finally {
      if (mounted) setState(() => _isLoadingParticipants = false);
    }
  }

  Future<void> _fetchDocuments() async {
    if (widget.tripData == null || widget.tripData!['_id'] == null) return;
    try {
      final response = await _documentService.getTripDocuments(widget.tripData!['_id']);
      if (response['success'] == true && mounted) {
        final List<dynamic> allDocs = response['documents'];
        setState(() {
          final titleLower = widget.title?.toLowerCase() ?? '';
          if (titleLower == 'trip documents') {
            _allDocs = allDocs.where((d) => d['type'] == 'Trip').toList();
          } else if (titleLower == 'my documents') {
            _allDocs = allDocs.where((d) => (d['type'] == 'Personal' || d['type'] == null) && d['isMine'] == true).toList();
          } else if (titleLower == 'family member documents' || titleLower == 'member documents') {
            _allDocs = allDocs.where((d) => 
              d['type'] == 'Family' || 
              (d['type'] == 'Personal' && d['isMine'] == false)
            ).toList();
          } else {
             // For specific member folder
             _allDocs = allDocs.where((d) {
               bool matches = false;
               if (widget.ownerId != null && d['belongsTo'] != null) {
                 if (d['belongsTo'] is Map) {
                   matches = d['belongsTo']['_id'] == widget.ownerId;
                 } else {
                   matches = d['belongsTo'] == widget.ownerId;
                 }
               }
               if (!matches && widget.ownerName != null) {
                 if (d['memberName'] != null) {
                   matches = d['memberName'] == widget.ownerName;
                 } else if (d['belongsTo'] != null) {
                   if (d['belongsTo'] is Map) {
                     final fName = d['belongsTo']['firstName'] ?? '';
                     final lName = d['belongsTo']['lastName'] ?? '';
                     matches = '$fName $lName'.trim() == widget.ownerName;
                   } else if (d['belongsTo'] is String) {
                     matches = d['belongsTo'] == widget.ownerName;
                   }
                 }
               }
               return matches || (d['type'] == 'Family' && d['memberName'] == widget.ownerName);
             }).toList();
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching docs: $e');
    }
  }

  List<dynamic> get _filteredDocs {
    return _allDocs.where((doc) {
      final name = doc['name'] ?? '';
      final number = doc['number'] ?? '';
      final matchesSearch = name.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          number.toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).map((doc) {
      return {
        ...doc,
        'name': doc['name'] ?? 'Document',
        'number': doc['number'] ?? 'N/A',
        'category': doc['category'] ?? doc['type'] ?? 'Personal',
        'format': doc['format'] ?? (doc['fileUrl'] != null ? doc['fileUrl'].split('.').last.toUpperCase() : 'PDF'),
        'size': doc['size'] ?? 'Unknown Size',
        'date': doc['date'] ?? 'Recent',
        'icon': doc['icon'] ?? Icons.description_outlined,
        'color': doc['color'] ?? const Color(0xFF0284C7),
      };
    }).toList();
  }

  void _openDocument(dynamic doc) async {
    final fileUrl = doc['fileUrl']?.toString();
    if (fileUrl == null || fileUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File URL is not available')),
        );
      }
      return;
    }

    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      // baseUrl is usually http://<ip>:5000/api, we just want http://<ip>:5000
      final rootUrl = baseUrl.replaceAll('/api', '');
      
      // Ensure the path uses forward slashes and avoid double slashes
      var cleanPath = fileUrl.replaceAll('\\', '/');
      if (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.substring(1);
      }

      final fullUrl = '$rootUrl/$cleanPath';
      final uri = Uri.parse(fullUrl);

      // Bypass canLaunchUrl check because of Android 11+ package visibility rules
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback to in-app browser if external fails
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }

      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
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

  void _showUploadDialog() {
    String selectedDocName = '';
    String enteredDocNumber = '';
    String? selectedFilePath;
    String belongsTo = widget.ownerId ?? widget.ownerName ?? '';
    String memberName = widget.ownerName ?? '';
    
    String documentType = 'Personal';
    if (widget.title == 'Trip Documents') {
      documentType = 'Trip';
    } else if (widget.title == 'Family Member Documents' || (widget.isFamilyLeader && widget.ownerName != null)) {
      documentType = 'Family';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Upload Document',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Document Name', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          TextField(
                            onChanged: (val) => selectedDocName = val,
                            decoration: InputDecoration(
                              hintText: 'e.g. Aadhaar Card, Passport',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Text('Document Number (Optional)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          TextField(
                            onChanged: (val) => enteredDocNumber = val,
                            decoration: InputDecoration(
                              hintText: 'Enter document number',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (documentType == 'Family' && widget.ownerName == null) ...[
                            const Text('Family Member Name', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            TextField(
                              onChanged: (val) {
                                belongsTo = val;
                                memberName = val;
                              },
                              decoration: InputDecoration(
                                hintText: 'Enter family member name',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          const Text('Upload File', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final file = await FilePicker.pickFile(
                                type: FileType.custom,
                                allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
                              );
                              if (file != null) {
                                setModalState(() {
                                  selectedFilePath = file.path;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF0072FF).withOpacity(0.3),
                                  style: BorderStyle.solid,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                          )
                                        ],
                                      ),
                                      child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF0072FF), size: 28),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      selectedFilePath != null 
                                        ? selectedFilePath!.split('/').last 
                                        : 'Tap to browse files',
                                      style: TextStyle(
                                        color: selectedFilePath != null ? AppColors.textPrimary : const Color(0xFF0072FF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (selectedFilePath == null) ...[
                                      const SizedBox(height: 4),
                                      const Text(
                                        'PDF, JPG or PNG (max. 10MB)',
                                        style: TextStyle(color: AppColors.textLight, fontSize: 12),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isUploading ? null : () async {
                                if (selectedDocName.isEmpty || selectedFilePath == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a name and select a file')),
                                  );
                                  return;
                                }
                                if (widget.tripData == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Trip context is missing!')),
                                  );
                                  return;
                                }

                                setModalState(() => _isUploading = true);
                                setState(() => _isUploading = true);

                                try {
                                  final response = await _documentService.uploadDocument(
                                    tripId: widget.tripData!['_id'],
                                    filePath: selectedFilePath!,
                                    name: selectedDocName,
                                    number: enteredDocNumber,
                                    type: documentType,
                                    belongsTo: (documentType == 'Family' || widget.ownerId != null) ? belongsTo : null,
                                    memberName: (documentType == 'Family') ? memberName : (widget.ownerId != null ? widget.ownerName : null),
                                  );

                                    if (response['success'] == true) {
                                      Navigator.pop(context); // close modal
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Document uploaded successfully')),
                                      );
                                      // Add to local list dynamically
                                      if (response['document'] != null) {
                                        setState(() {
                                          final newDoc = Map<String, dynamic>.from(response['document']);
                                          newDoc['color'] = newDoc['name'].toString().toLowerCase().contains('flight') ? const Color(0xFF8B5CF6) : AppColors.primary;
                                          newDoc['icon'] = newDoc['name'].toString().toLowerCase().contains('flight') ? Icons.flight_takeoff_outlined : Icons.description_outlined;
                                          _allDocs.insert(0, newDoc);
                                        });
                                      }
                                    } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(response['message'] ?? 'Failed to upload')),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('An error occurred during upload')),
                                  );
                                } finally {
                                  if (mounted) {
                                    setModalState(() => _isUploading = false);
                                    setState(() => _isUploading = false);
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0072FF),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: _isUploading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text(
                                      'Upload Document',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDocs;
    final titleLower = widget.title?.toLowerCase() ?? '';
    final isGroupedView = titleLower == 'member documents' || titleLower == 'family member documents';

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
      floatingActionButton: (widget.tripData != null && !isGroupedView) ? FloatingActionButton(
        onPressed: _showUploadDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
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
          // Documents grid
          Expanded(
            child: Builder(
              builder: (context) {
                if (filtered.isEmpty && !isGroupedView) {
                  return Center(
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
                  );
                }

                if (isGroupedView) {
                  if (_isLoadingParticipants) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF0072FF)));
                  }

                  Map<String, List<dynamic>> memberGroups = {};
                  Map<String, String> participantIds = {};
                  Map<String, String> participantAvatars = {};

                  // Initialize empty groups for all participants
                  for (var p in _participants) {
                    String name = p['name'] ?? 'Unknown';
                    if (name.isEmpty) name = 'Unknown';
                    
                    memberGroups[name] = [];
                    // For unregistered members, userId might be null or missing
                    participantIds[name] = p['userId']?.toString() ?? '';
                    participantAvatars[name] = p['avatar']?.toString() ?? '';
                  }

                  // Distribute documents into these groups
                  for (var doc in filtered) {
                    String owner = 'Unknown';
                    if (doc['memberName'] != null && doc['memberName'].toString().trim().isNotEmpty) {
                      owner = doc['memberName'];
                    } else if (doc['belongsTo'] != null) {
                      if (doc['belongsTo'] is Map) {
                        final fName = doc['belongsTo']['firstName'] ?? '';
                        final lName = doc['belongsTo']['lastName'] ?? '';
                        if (fName.isNotEmpty || lName.isNotEmpty) {
                          owner = '$fName $lName'.trim();
                        }
                      } else if (doc['belongsTo'] is String) {
                        owner = doc['belongsTo'];
                      }
                    }
                    
                    // Fallback to check if owner is an ID that matches a participant or doc fields match
                    for (var p in _participants) {
                      final pName = p['name']?.toString() ?? '';
                      final pUserId = p['userId']?.toString() ?? '';
                      final pId = p['_id']?.toString() ?? p['id']?.toString() ?? '';
                      final docBelongsTo = doc['belongsTo'] is Map ? (doc['belongsTo']['_id']?.toString() ?? '') : doc['belongsTo']?.toString() ?? '';
                      final docMemberName = doc['memberName']?.toString() ?? '';

                      if (pName.isNotEmpty && (
                          owner == pName || 
                          docMemberName == pName ||
                          (pUserId.isNotEmpty && (owner == pUserId || docBelongsTo == pUserId)) ||
                          (pId.isNotEmpty && (owner == pId || docBelongsTo == pId))
                        )) {
                        owner = pName;
                        break;
                      }
                    }

                    if (!memberGroups.containsKey(owner)) {
                      memberGroups[owner] = [];
                    }
                    memberGroups[owner]!.add(doc);
                  }

                  final owners = memberGroups.keys.toList();

                  if (owners.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.people_outline, size: 48, color: AppColors.textLight),
                          SizedBox(height: 12),
                          Text(
                            'No members found',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: owners.length,
                    itemBuilder: (context, index) {
                      final ownerName = owners[index];
                      final ownerDocs = memberGroups[ownerName]!;
                      String groupAvatar = participantAvatars[ownerName] ?? '';
                      if (groupAvatar.isEmpty && ownerDocs.isNotEmpty && ownerDocs.first['belongsTo'] is Map) {
                        groupAvatar = ownerDocs.first['belongsTo']['profilePhoto'] ?? '';
                      }
                      
                      String initials = '';
                      if (ownerName.isNotEmpty && ownerName != 'Unknown') {
                        List<String> parts = ownerName.trim().split(RegExp(r'\s+'));
                        if (parts.length > 1) {
                          initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
                        } else {
                          initials = parts[0][0].toUpperCase();
                        }
                      } else {
                        initials = '?';
                      }

                      Widget avatarWidget;
                      if (groupAvatar.isNotEmpty && !groupAvatar.contains('images.unsplash.com')) {
                        avatarWidget = CircleAvatar(
                          radius: 28,
                          backgroundImage: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(groupAvatar)),
                        );
                      } else {
                        avatarWidget = CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFF0072FF),
                          child: Text(
                            initials,
                            style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        );
                      }

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AllDocumentsScreen(
                                title: '$ownerName\'s Documents',
                                documents: ownerDocs,
                                tripData: widget.tripData,
                                isFamilyLeader: widget.isFamilyLeader,
                                ownerId: participantIds[ownerName] != null && participantIds[ownerName]!.isNotEmpty ? participantIds[ownerName] : null,
                                ownerName: ownerName,
                              ),
                            ),
                          ).then((_) => _fetchDocuments());
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              avatarWidget,
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  ownerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${ownerDocs.length} Documents',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }

                // Normal Document Grid View
                return GridView.builder(
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
                      onTap: () => _openDocument(doc),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
