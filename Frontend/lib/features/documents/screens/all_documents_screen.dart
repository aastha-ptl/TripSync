import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/document_service.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_endpoints.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import '../../trip/services/trip_service.dart';
import '../../profile/services/user_service.dart';

class AllDocumentsScreen extends StatefulWidget {
  final String? title;
  final List<dynamic>? documents;
  final Map<String, dynamic>? tripData;
  final bool isFamilyLeader;
  final bool isFromMemberDocs;
  final String? ownerId;
  final String? ownerName;

  const AllDocumentsScreen({
    super.key,
    this.title,
    this.documents,
    this.tripData,
    this.isFamilyLeader = false,
    this.isFromMemberDocs = false,
    this.ownerId,
    this.ownerName,
  });

  @override
  State<AllDocumentsScreen> createState() => _AllDocumentsScreenState();
}

class _AllDocumentsScreenState extends State<AllDocumentsScreen> {
  String _searchQuery = '';
  List<dynamic> _allDocs = [];
  bool _isUploading = false;
  final DocumentService _documentService = DocumentService();
  
  bool _isLoadingParticipants = false;
  List<Map<String, dynamic>> _participants = [];
  Set<String> _myFamilyNames = {};
  Set<String> _myFamilyIds = {};

  bool get _isTripLeaderOrCreator {
    final role = widget.tripData?['role']?.toString().toLowerCase();
    final origRole = widget.tripData?['originalRole']?.toString().toLowerCase();
    return role == 'trip leader' || origRole == 'creator' || origRole == 'tripleader' || origRole == 'admin';
  }

  bool get _isFamilyLeader {
    if (widget.isFamilyLeader) return true;
    final role = widget.tripData?['role']?.toString().toLowerCase();
    final origRole = widget.tripData?['originalRole']?.toString().toLowerCase();
    if (role == 'family leader' || role == 'familyleader' || origRole == 'family leader' || origRole == 'familyleader') {
      return true;
    }
    final titleLower = widget.title?.toLowerCase() ?? '';
    if (titleLower == 'my family documents') {
      return true;
    }
    return false;
  }

  bool get _canUpload {
    if (widget.isFromMemberDocs) return false;
    if (widget.tripData == null) return false;
    final titleLower = widget.title?.toLowerCase() ?? '';
    final isGrouped = titleLower == 'member documents' || 
                      titleLower == 'family member documents' || 
                      titleLower == 'my family documents';
    if (isGrouped) return false;

    // For Trip Documents, only trip leader or creator can upload
    if (titleLower == 'trip documents') {
      return _isTripLeaderOrCreator;
    }

    // When viewing any specific member's documents:
    // Only Family Leader can upload for their family members inside "My Family Documents".
    // When viewing from "Member Documents", upload is disabled (+ button removed).
    if (widget.ownerName != null || widget.ownerId != null || titleLower.contains('\'s documents')) {
      return widget.isFamilyLeader;
    }

    // Personal documents ("My Documents"): can upload
    return true;
  }

  @override
  void initState() {
    super.initState();
    _allDocs = widget.documents != null 
        ? List<dynamic>.from(widget.documents!)
        : [];
        
    final titleLower = widget.title?.toLowerCase() ?? '';
    final isGroupedView = titleLower == 'member documents' || 
                          titleLower == 'family member documents' || 
                          titleLower == 'my family documents';
    if (isGroupedView) {
      _fetchParticipants();
    } else {
      _fetchDocuments();
    }
  }

  Future<void> _fetchParticipants() async {
    final tripId = (widget.tripData?['_id'] ?? widget.tripData?['id'])?.toString();
    if (tripId == null) return;
    setState(() => _isLoadingParticipants = true);
    try {
      final tripService = TripService();
      final userService = UserService();
      
      final profileRes = await userService.getProfile();
      final currentUserId = profileRes['success'] == true ? profileRes['data']['_id']?.toString() : null;
      final currentProfilePhoto = profileRes['success'] == true ? profileRes['data']['profilePhoto']?.toString() : null;

      final titleLower = widget.title?.toLowerCase() ?? '';
      final isMyFamilyDocs = titleLower == 'my family documents';

      if (isMyFamilyDocs) {
        // Person with Family: Show "You" folder first, then family members
        List<Map<String, dynamic>> list = [];
        list.add({
          'name': 'You',
          'userId': currentUserId,
          'id': currentUserId,
          'avatar': currentProfilePhoto ?? '',
          'isYou': true,
        });

        // 1. Fetch from getMyFamily
        final famRes = await tripService.getMyFamily(tripId);
        if (famRes['success'] == true && famRes['data'] != null) {
          final fam = famRes['data']['family'];
          if (fam != null && fam['members'] is List) {
            for (var fm in fam['members']) {
              if (fm is Map) {
                list.add({
                  'name': fm['name'] ?? 'Family Member',
                  'userId': fm['userId'] ?? fm['_id'] ?? fm['id'],
                  'id': fm['_id'] ?? fm['id'],
                  'avatar': fm['avatar'] ?? fm['profilePhoto'] ?? '',
                  'relationship': fm['relationship'] ?? '',
                  'isYou': false,
                });
              }
            }
          }
        }

        // 2. Fallback check from getTripParticipants if no members were added yet
        if (list.length == 1) {
          final response = await tripService.getTripParticipants(tripId);
          if (response['success'] == true && response['data'] is List) {
            final List<Map<String, dynamic>> allParticipants = List<Map<String, dynamic>>.from(response['data']);
            final myP = allParticipants.firstWhere(
              (p) => p['userId']?.toString() == currentUserId || p['id']?.toString() == currentUserId,
              orElse: () => <String, dynamic>{},
            );
            if (myP.isNotEmpty && myP['familyMembers'] is List) {
              for (var fm in myP['familyMembers']) {
                if (fm is Map) {
                  list.add({
                    'name': fm['name'] ?? 'Family Member',
                    'userId': fm['userId'] ?? fm['_id'] ?? fm['id'],
                    'id': fm['_id'] ?? fm['id'],
                    'avatar': fm['avatar'] ?? fm['profilePhoto'] ?? '',
                    'relationship': fm['relationship'] ?? '',
                    'isYou': false,
                  });
                }
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _participants = list;
          });
        }
        await _fetchDocuments();
        return;
      }

      Set<String> myFamNames = {};
      Set<String> myFamIds = {};
      if (currentUserId != null) {
        myFamIds.add(currentUserId);
      }
      try {
        final famRes = await tripService.getMyFamily(tripId);
        if (famRes['success'] == true && famRes['data'] != null) {
          final fam = famRes['data']['family'];
          if (fam != null && fam['members'] is List) {
            for (var fm in fam['members']) {
              if (fm is Map) {
                final name = fm['name']?.toString().trim();
                if (name != null && name.isNotEmpty) myFamNames.add(name.toLowerCase());
                final mId = (fm['_id'] ?? fm['id'] ?? fm['userId'])?.toString().trim();
                if (mId != null && mId.isNotEmpty) myFamIds.add(mId);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting my family info: $e');
      }

      final response = await tripService.getTripParticipants(tripId);
      if (response['success'] == true && mounted) {
        final List<Map<String, dynamic>> allParticipants = List<Map<String, dynamic>>.from(response['data']);
        
        // Also extract from allParticipants if current user has a family entry there
        for (var p in allParticipants) {
          final uId = p['userId']?.toString();
          if (uId != null && currentUserId != null && uId == currentUserId) {
            if (p['familyMembers'] != null && p['familyMembers'] is List) {
              for (var fm in p['familyMembers']) {
                if (fm is Map) {
                  final name = fm['name']?.toString().trim();
                  if (name != null && name.isNotEmpty) myFamNames.add(name.toLowerCase());
                  final mId = (fm['_id'] ?? fm['id'] ?? fm['userId'])?.toString().trim();
                  if (mId != null && mId.isNotEmpty) myFamIds.add(mId);
                }
              }
            }
          }
        }

        setState(() {
          _myFamilyNames = myFamNames;
          _myFamilyIds = myFamIds;
        });

        List<Map<String, dynamic>> list = [];
        
        // Trip Leader / Creator can see all OTHER trip members across other families and individuals.
        // The Trip Leader and their own family members are excluded (they belong in "My Family Documents").
        if (_isTripLeaderOrCreator) {
          for (var p in allParticipants) {
            final uId = p['userId']?.toString();
            // Don't show leader himself or leader's family group in Member Documents
            if (uId != null && currentUserId != null && uId == currentUserId) {
              continue;
            }

            if (p['type'] == 'Family') {
              final pName = (p['name']?.toString().trim() ?? '').toLowerCase();
              final pId = ((p['_id'] ?? p['id'])?.toString() ?? '').trim();
              if (!myFamNames.contains(pName) && !myFamIds.contains(pId)) {
                list.add({
                  'name': p['name'],
                  'userId': p['userId'],
                  'id': p['id'] ?? p['_id'],
                  'avatar': p['avatar'],
                  'role': p['role'] ?? 'familyLeader',
                });
              }
              if (p['familyMembers'] != null && p['familyMembers'] is List) {
                for (var fm in p['familyMembers']) {
                  if (fm is Map) {
                    final fmName = (fm['name']?.toString().trim() ?? '').toLowerCase();
                    final fmId = ((fm['_id'] ?? fm['id'] ?? fm['userId'])?.toString() ?? '').trim();
                    // Exclude if it's the leader's own family member
                    if (!myFamNames.contains(fmName) && !myFamIds.contains(fmId)) {
                      list.add(Map<String, dynamic>.from(fm));
                    }
                  }
                }
              }
            } else {
              final pName = (p['name']?.toString().trim() ?? '').toLowerCase();
              final pId = ((p['_id'] ?? p['id'] ?? p['userId'])?.toString() ?? '').trim();
              if (!myFamNames.contains(pName) && !myFamIds.contains(pId)) {
                list.add(p);
              }
            }
          }
        } else if (widget.isFamilyLeader && currentUserId != null) {
          final myFamily = allParticipants.firstWhere(
            (p) => p['type'] == 'Family' && p['userId']?.toString() == currentUserId,
            orElse: () => <String, dynamic>{},
          );
          if (myFamily.isNotEmpty && myFamily['familyMembers'] != null) {
            list = List<Map<String, dynamic>>.from(myFamily['familyMembers']);
          }
        } else {
          for (var p in allParticipants) {
            final user = p['userId']?.toString();
            if (user != null && currentUserId != null && user == currentUserId) {
              continue;
            }
            final pName = (p['name']?.toString().trim() ?? '').toLowerCase();
            final pId = ((p['_id'] ?? p['id'] ?? p['userId'])?.toString() ?? '').trim();
            if (myFamNames.contains(pName) || myFamIds.contains(pId)) continue;

            list.add(p);
            if (p['familyMembers'] != null && p['familyMembers'] is List) {
              for (var fm in p['familyMembers']) {
                if (fm is Map) {
                  final fmName = (fm['name']?.toString().trim() ?? '').toLowerCase();
                  final fmId = ((fm['_id'] ?? fm['id'] ?? fm['userId'])?.toString() ?? '').trim();
                  if (!myFamNames.contains(fmName) && !myFamIds.contains(fmId)) {
                    list.add(Map<String, dynamic>.from(fm));
                  }
                }
              }
            }
          }
        }

        setState(() {
          _participants = list;
        });
        await _fetchDocuments();
      }
    } catch (e) {
      debugPrint('Error fetching participants: $e');
    } finally {
      if (mounted) setState(() => _isLoadingParticipants = false);
    }
  }

  bool _isNameMatch(String name1, String name2) {
    final n1 = name1.trim().toLowerCase();
    final n2 = name2.trim().toLowerCase();
    if (n1.isEmpty || n2.isEmpty) return false;
    if (n1 == n2) return true;
    if (n1.contains(n2) || n2.contains(n1)) {
      final words1 = n1.split(RegExp(r'\s+'));
      final words2 = n2.split(RegExp(r'\s+'));
      if (words1.isNotEmpty && words2.isNotEmpty && words1.first == words2.first) {
        return true;
      }
      if (words1.contains(n2) || words2.contains(n1)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _fetchDocuments() async {
    final tripId = (widget.tripData?['_id'] ?? widget.tripData?['id'])?.toString();
    if (tripId == null) return;
    try {
      final response = await _documentService.getTripDocuments(tripId);
      if (response['success'] == true && mounted) {
        final List<dynamic> allDocs = response['documents'];
        setState(() {
          final titleLower = widget.title?.toLowerCase() ?? '';
          if (titleLower == 'trip documents') {
            _allDocs = allDocs.where((d) => d['type'] == 'Trip').toList();
          } else if (titleLower == 'my documents') {
            _allDocs = allDocs.where((d) => (d['type'] == 'Personal' || d['type'] == null) && d['isMine'] == true).toList();
          } else if (titleLower == 'my family documents') {
            final myFamilyNames = _participants.map((p) => (p['name']?.toString().trim() ?? '').toLowerCase()).where((n) => n.isNotEmpty && n != 'you').toSet();
            final myFamilyIds = _participants.map((p) => (p['userId']?.toString() ?? p['id']?.toString() ?? '').trim()).where((id) => id.isNotEmpty).toSet();

            _allDocs = allDocs.where((d) {
              if (d['type'] == 'Trip') return false;

              // 1. Leader's personal documents
              if (d['isMine'] == true) return true;

              final mName = (d['memberName']?.toString().trim() ?? '').toLowerCase();
              final bId = (d['belongsTo'] is Map 
                  ? (d['belongsTo']['_id']?.toString() ?? '') 
                  : (d['belongsToId']?.toString() ?? d['belongsTo']?.toString() ?? '')).trim();

              // 2. Check if memberName matches any of leader's family members
              if (mName.isNotEmpty) {
                for (var famName in myFamilyNames) {
                  if (_isNameMatch(famName, mName)) {
                    return true;
                  }
                }
              }

              // 3. Check if belongsTo matches any of leader's family member IDs
              if (bId.isNotEmpty && myFamilyIds.contains(bId)) {
                return true;
              }

              return false;
            }).toList();
          } else if (titleLower == 'family member documents' || titleLower == 'member documents') {
            _allDocs = allDocs.where((d) {
              if (d['isMine'] == true || d['type'] == 'Trip') return false;

              final mName = (d['memberName']?.toString().trim() ?? '').toLowerCase();
              final bId = (d['belongsTo'] is Map 
                  ? (d['belongsTo']['_id']?.toString() ?? '') 
                  : (d['belongsToId']?.toString() ?? d['belongsTo']?.toString() ?? '')).trim();

              // Exclude leader's family members' documents from Member Documents
              if (mName.isNotEmpty) {
                for (var famName in _myFamilyNames) {
                  if (_isNameMatch(famName, mName)) return false;
                }
              }
              if (bId.isNotEmpty && _myFamilyIds.contains(bId)) {
                return false;
              }

              return true;
            }).toList();
          } else {
             // For specific member folder
             final ownerIdStr = widget.ownerId?.toString().trim() ?? '';
             final ownerNameStr = (widget.ownerName?.toString().trim() ?? '').toLowerCase();

             _allDocs = allDocs.where((d) {
               // Shared trip documents belong in Trip Documents, never in individual member folders
               if (d['type'] == 'Trip') {
                 return false;
               }

               final docMemberName = (d['memberName']?.toString().trim() ?? '').toLowerCase();
               final docBelongsToId = (d['belongsTo'] is Map 
                   ? (d['belongsTo']['_id']?.toString() ?? '') 
                   : (d['belongsToId']?.toString() ?? d['belongsTo']?.toString() ?? '')).trim();

               String docBelongsToName = '';
               if (d['belongsTo'] is Map) {
                 final fName = d['belongsTo']['firstName']?.toString().trim() ?? '';
                 final lName = d['belongsTo']['lastName']?.toString().trim() ?? '';
                 docBelongsToName = '$fName $lName'.trim().toLowerCase();
               }

               // 1. Priority: Match by memberName if specified
               if (docMemberName.isNotEmpty) {
                 return _isNameMatch(docMemberName, ownerNameStr);
               }

               // 2. Match by belongsTo ID (userId or member subdocument _id)
               if (ownerIdStr.isNotEmpty && docBelongsToId.isNotEmpty && docBelongsToId == ownerIdStr) {
                 return true;
               }

               // 3. Match by belongsTo person full name
               if (ownerNameStr.isNotEmpty && docBelongsToName.isNotEmpty && _isNameMatch(docBelongsToName, ownerNameStr)) {
                 return true;
               }

               return false;
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

  void _showUploadDialog() {
    String selectedDocName = '';
    String enteredDocNumber = '';
    String? selectedFilePath;
    String belongsTo = widget.ownerId ?? widget.ownerName ?? '';
    String memberName = widget.ownerName ?? '';
    
    String documentType = 'Personal';
    if (widget.title == 'Trip Documents') {
      documentType = 'Trip';
    } else if (widget.title == 'Family Member Documents' || widget.ownerName != null || (_isFamilyLeader && widget.ownerName != null)) {
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
                        Text(
                          widget.ownerName != null 
                              ? 'Upload for ${widget.ownerName}' 
                              : 'Upload Document',
                          style: const TextStyle(
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
                                final tripId = (widget.tripData?['_id'] ?? widget.tripData?['id'])?.toString();
                                if (tripId == null || tripId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Trip context is missing!')),
                                  );
                                  return;
                                }

                                setModalState(() => _isUploading = true);
                                setState(() => _isUploading = true);

                                try {
                                  final response = await _documentService.uploadDocument(
                                    tripId: tripId,
                                    filePath: selectedFilePath!,
                                    name: selectedDocName,
                                    number: enteredDocNumber,
                                    type: documentType,
                                    belongsTo: (documentType == 'Family' || widget.ownerId != null) ? belongsTo : null,
                                    memberName: widget.ownerName ?? ((documentType == 'Family') ? memberName : null),
                                  );

                                  if (!mounted) return;

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
                                    await _fetchDocuments();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(response['message'] ?? 'Failed to upload')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('An error occurred during upload')),
                                    );
                                  }
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
    final isMyFamilyDocs = titleLower == 'my family documents';
    final isGroupedView = titleLower == 'member documents' || 
                          titleLower == 'family member documents' || 
                          isMyFamilyDocs;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
              isGroupedView
                  ? '${_participants.length} ${_participants.length == 1 ? 'member' : 'members'} available'
                  : '${filtered.length} ${filtered.length == 1 ? 'document' : 'documents'} available',
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
      floatingActionButton: _canUpload ? FloatingActionButton(
        onPressed: _showUploadDialog,
        backgroundColor: const Color(0xFF0072FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ) : null,
      body: Column(
        children: [
          // Search header only shown on document views (Image 3)
          if (!isGroupedView)
            Container(
              padding: const EdgeInsets.all(16),
              child: Container(
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
                    prefixIcon: Icon(Icons.search, color: Color(0xFF0072FF), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                ),
              ),
            ),
          // Content view
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
                  Map<String, bool> isYouMap = {};

                  // Initialize empty groups for all participants
                  for (var p in _participants) {
                    String name = p['name'] ?? 'Unknown';
                    if (name.isEmpty) name = 'Unknown';
                    
                    memberGroups[name] = [];
                    participantIds[name] = p['userId']?.toString() ?? p['id']?.toString() ?? '';
                    participantAvatars[name] = p['avatar']?.toString() ?? '';
                    isYouMap[name] = p['isYou'] == true || name == 'You';
                  }

                  // Distribute documents into these groups
                  for (var doc in filtered) {
                    if (doc['type'] == 'Trip') {
                      continue;
                    }

                    final docMemberName = (doc['memberName']?.toString().trim() ?? '').toLowerCase();
                    final docBelongsToId = (doc['belongsTo'] is Map 
                        ? (doc['belongsTo']['_id']?.toString() ?? '') 
                        : (doc['belongsToId']?.toString() ?? doc['belongsTo']?.toString() ?? '')).trim();
                    
                    String docBelongsToName = '';
                    if (doc['belongsTo'] is Map) {
                      final fName = doc['belongsTo']['firstName']?.toString().trim() ?? '';
                      final lName = doc['belongsTo']['lastName']?.toString().trim() ?? '';
                      docBelongsToName = '$fName $lName'.trim().toLowerCase();
                    }

                    String? matchedOwner;

                    // Pass 1: Prioritize matching by memberName across all participants (excluding "You")
                    // This is essential because family members share the Family Leader's account/belongsToId.
                    // Checking memberName first prevents family member documents from being incorrectly attributed to the Family Leader.
                    if (docMemberName.isNotEmpty) {
                      for (var p in _participants) {
                        if (p['isYou'] == true || p['name'] == 'You') continue;
                        final pName = (p['name']?.toString().trim() ?? '');
                        if (_isNameMatch(pName, docMemberName)) {
                          matchedOwner = p['name'];
                          break;
                        }
                      }
                    }

                    // Pass 2: If no memberName matched, match by belongsTo ID (userId or member subdocument _id)
                    if (matchedOwner == null && docBelongsToId.isNotEmpty) {
                      for (var p in _participants) {
                        if (p['isYou'] == true || p['name'] == 'You') continue;
                        final pUserId = (p['userId']?.toString() ?? '').trim();
                        final pId = ((p['_id'] ?? p['id'])?.toString() ?? '').trim();
                        if (docBelongsToId == pUserId || docBelongsToId == pId) {
                          matchedOwner = p['name'];
                          break;
                        }
                      }
                    }

                    // Pass 3: Match by belongsTo user full name
                    if (matchedOwner == null && docBelongsToName.isNotEmpty) {
                      for (var p in _participants) {
                        if (p['isYou'] == true || p['name'] == 'You') continue;
                        final pName = (p['name']?.toString().trim() ?? '');
                        if (_isNameMatch(pName, docBelongsToName)) {
                          matchedOwner = p['name'];
                          break;
                        }
                      }
                    }

                    // Pass 4: Fallback to "You" only if it belongs to current user
                    if (matchedOwner == null) {
                      if (doc['isMine'] == true || docMemberName == 'you') {
                        matchedOwner = 'You';
                      }
                    }

                    if (isMyFamilyDocs) {
                      // In "My Family Documents", ONLY add documents to folders of participants in _participants
                      if (matchedOwner != null && memberGroups.containsKey(matchedOwner)) {
                        memberGroups[matchedOwner]!.add(doc);
                      }
                    } else {
                      // In other views (like Member Documents):
                      // Do not add leader or leader's family members to member groups
                      if (matchedOwner == 'You') continue;
                      if (matchedOwner != null) {
                        bool isOwnFamily = false;
                        for (var famName in _myFamilyNames) {
                          if (_isNameMatch(famName, matchedOwner)) {
                            isOwnFamily = true;
                            break;
                          }
                        }
                        if (_myFamilyIds.contains(participantIds[matchedOwner])) {
                          isOwnFamily = true;
                        }
                        if (isOwnFamily) continue;
                      }

                      if (matchedOwner == null && doc['memberName'] != null && doc['memberName'].toString().trim().isNotEmpty) {
                        final potentialName = doc['memberName'].toString().trim();
                        bool isOwnFamily = false;
                        for (var famName in _myFamilyNames) {
                          if (_isNameMatch(famName, potentialName)) {
                            isOwnFamily = true;
                            break;
                          }
                        }
                        if (!isOwnFamily) {
                          matchedOwner = potentialName;
                        }
                      }
                      if (matchedOwner != null) {
                        if (!memberGroups.containsKey(matchedOwner)) {
                          memberGroups[matchedOwner] = [];
                          if (doc['belongsTo'] is Map && doc['belongsTo']['profilePhoto'] != null) {
                            participantAvatars[matchedOwner] = doc['belongsTo']['profilePhoto'];
                          }
                        }
                        memberGroups[matchedOwner]!.add(doc);
                      }
                    }
                  }

                  final owners = isMyFamilyDocs
                      ? _participants.map((p) => p['name']?.toString() ?? 'Unknown').where((n) => memberGroups.containsKey(n)).toList()
                      : memberGroups.keys.toList();

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

                  // Folder Grid View (Image 2)
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.88,
                    ),
                    itemCount: owners.length,
                    itemBuilder: (context, index) {
                      final ownerName = owners[index];
                      final ownerDocs = memberGroups[ownerName] ?? [];
                      final isThisYou = isYouMap[ownerName] == true || ownerName == 'You';
                      String groupAvatar = participantAvatars[ownerName] ?? '';
                      if (groupAvatar.isEmpty && ownerDocs.isNotEmpty && ownerDocs.first['belongsTo'] is Map) {
                        groupAvatar = ownerDocs.first['belongsTo']['profilePhoto'] ?? '';
                      } else if (groupAvatar.isEmpty && ownerDocs.isNotEmpty && ownerDocs.first['uploadedBy'] is Map) {
                        groupAvatar = ownerDocs.first['uploadedBy']['profilePhoto'] ?? '';
                      }
                      
                      String initials = '';
                      if (isThisYou) {
                        initials = 'You';
                      } else if (ownerName.isNotEmpty && ownerName != 'Unknown') {
                        List<String> parts = ownerName.trim().split(RegExp(r'\s+'));
                        if (parts.length > 1) {
                          initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
                        } else {
                          initials = parts[0][0].toUpperCase();
                        }
                      } else {
                        initials = '?';
                      }

                      final colors = [
                        const Color(0xFF0072FF),
                        const Color(0xFF0066FF),
                        const Color(0xFF4F46E5),
                        const Color(0xFF7C3AED),
                      ];
                      final bgCol = isThisYou ? const Color(0xFF0072FF) : colors[index % colors.length];

                      Widget avatarWidget;
                      if (groupAvatar.isNotEmpty && !groupAvatar.contains('images.unsplash.com')) {
                        avatarWidget = CircleAvatar(
                          radius: 36,
                          backgroundImage: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(groupAvatar)),
                        );
                      } else {
                        avatarWidget = CircleAvatar(
                          radius: 36,
                          backgroundColor: bgCol,
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: isThisYou ? 16 : 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AllDocumentsScreen(
                                title: isThisYou ? 'My Documents' : '$ownerName\'s Documents',
                                documents: ownerDocs,
                                tripData: widget.tripData,
                                isFamilyLeader: isThisYou ? false : isMyFamilyDocs,
                                isFromMemberDocs: !isMyFamilyDocs,
                                ownerId: participantIds[ownerName] != null && participantIds[ownerName]!.isNotEmpty ? participantIds[ownerName] : null,
                                ownerName: isThisYou ? null : ownerName,
                              ),
                            ),
                          ).then((_) => _fetchDocuments());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
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
                              const SizedBox(height: 16),
                              Text(
                                ownerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${ownerDocs.length} ${ownerDocs.length == 1 ? 'Document' : 'Documents'}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }

                // Document Grid View (Image 3)
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.12,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final String format = doc['format']?.toString().toUpperCase() ?? 'PDF';
                    final String size = doc['size']?.toString() ?? 'Unknown Size';
                    final String date = doc['date']?.toString() ?? 'Recent';
                    final String name = doc['name']?.toString() ?? 'Document';

                    return GestureDetector(
                      onTap: () => _openDocument(doc),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
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
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.description_outlined, color: Color(0xFF0284C7), size: 20),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    format,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  size,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                                Text(
                                  date,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
