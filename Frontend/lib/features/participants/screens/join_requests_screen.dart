import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({super.key});

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  final List<Map<String, dynamic>> _pendingRequests = [
    {
      'name': 'Karan Malhotra',
      'type': 'Solo',
      'group': 'Solo Traveler',
      'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&auto=format&fit=crop&q=80',
      'phone': '+91 98888 77777',
      'time': '2h ago',
    },
    {
      'name': 'Sneha Rao',
      'type': 'Family',
      'group': 'Rao Family',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&auto=format&fit=crop&q=80',
      'phone': '+91 97777 66666',
      'time': '5h ago',
    },
    {
      'name': 'Amit Sen',
      'type': 'Family',
      'group': 'Sen Family',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&auto=format&fit=crop&q=80',
      'phone': '+91 96666 55555',
      'time': '1d ago',
    },
  ];

  void _acceptRequest(int index) {
    final acceptedUser = _pendingRequests[index];
    setState(() {
      _pendingRequests.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${acceptedUser['name']} has been added to the trip!'),
        backgroundColor: const Color(0xFF20C060),
      ),
    );

    Navigator.pop(context, {
      'name': acceptedUser['name'],
      'role': 'Member',
      'type': acceptedUser['type'],
      'group': acceptedUser['group'],
      'avatar': acceptedUser['avatar'],
      'phone': acceptedUser['phone'],
    });
  }

  void _declineRequest(int index) {
    final declinedUser = _pendingRequests[index];
    setState(() {
      _pendingRequests.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Declined request from ${declinedUser['name']}'),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  void _showAddMemberDialog() {
    final nameController = TextEditingController();
    String selectedType = 'Solo';
    String selectedGroup = 'Solo Traveler';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Add Trip Member Manually', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Traveler Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Solo', child: Text('Solo Traveler')),
                      DropdownMenuItem(value: 'Family', child: Text('Family Member')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedType = val;
                          if (val == 'Solo') {
                            selectedGroup = 'Solo Traveler';
                          } else {
                            selectedGroup = 'Patel Family';
                          }
                        });
                      }
                    },
                  ),
                  if (selectedType == 'Family') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedGroup,
                      decoration: const InputDecoration(
                        labelText: 'Select Family Group',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Patel Family', child: Text('Patel Family')),
                        DropdownMenuItem(value: 'Mehta Family', child: Text('Mehta Family')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedGroup = val;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      final newUser = {
                        'name': nameController.text.trim(),
                        'role': 'Member',
                        'type': selectedType,
                        'group': selectedGroup,
                        'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&auto=format&fit=crop&q=80',
                        'phone': '+91 99900 11223',
                      };
                      Navigator.pop(context); // Pop dialog
                      Navigator.pop(context, newUser); // Pop screen and return new member
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Add', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Join Requests',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: _pendingRequests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Pending Requests',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'All travelers have been reviewed.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingRequests.length,
              itemBuilder: (context, index) {
                final req = _pendingRequests[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.01),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(req['avatar']),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req['name'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    req['group'],
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  req['time'],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Actions
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFFEF4444), size: 20),
                            onPressed: () => _declineRequest(index),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.check, color: Color(0xFF20C060), size: 20),
                            onPressed: () => _acceptRequest(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FloatingActionButton(
          onPressed: _showAddMemberDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
