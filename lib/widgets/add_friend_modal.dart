import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../services/friend_service.dart';

class AddFriendModal extends StatefulWidget {
  const AddFriendModal({super.key});

  @override
  State<AddFriendModal> createState() => _AddFriendModalState();
}

class _AddFriendModalState extends State<AddFriendModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final Set<String> _pendingRequests = {};
  final Set<String> _requestedUsers = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.green,
      ),
    );
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await FriendService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    }
  }
  
  Future<void> _sendFriendRequest(Map<String, dynamic> targetUser) async {
    final targetUserId = targetUser['uid'];
    final relationshipStatus = targetUser['relationshipStatus'] ?? 'none';
    
    // Prevent sending requests to friends or already requested users
    if (_pendingRequests.contains(targetUserId) || 
        _requestedUsers.contains(targetUserId) ||
        relationshipStatus == 'friend' ||
        relationshipStatus == 'requested') {
      return;
    }

    setState(() {
      _pendingRequests.add(targetUserId);
    });
    
    try {
      await FriendService.sendFriendRequest(targetUser, _showSnackBar);
      
      // Mark user as requested immediately after successful request
      setState(() {
        _requestedUsers.add(targetUserId);
        _pendingRequests.remove(targetUserId);
      });
    } catch (e) {
      setState(() {
        _pendingRequests.remove(targetUserId);
      });
      _showSnackBar('Failed to send friend request', backgroundColor: Colors.red);
    }
  }

  Widget _buildRelationshipWidget(Map<String, dynamic> user) {
    final userId = user['uid'];
    final relationshipStatus = user['relationshipStatus'] ?? 'none';
    final isPending = _pendingRequests.contains(userId);
    final isRequested = _requestedUsers.contains(userId);

    // Show loading spinner if currently sending request
    if (isPending) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (relationshipStatus) {
      case 'friend':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 16,
                color: Colors.green[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Friends',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      case 'requested':
      case 'isRequested': // Handle both cases
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 16,
                color: Colors.orange[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Requested',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      case 'pending':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_add,
                size: 16,
                color: Colors.blue[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Invited You',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      default: // 'none'
        if (isRequested) {
          return ShadButton(
            onPressed: null, // Disabled
            backgroundColor: Colors.grey[400],
            child: const Text(
              'Requested',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        } else {
          return ShadButton(
            onPressed: () => _sendFriendRequest(user),
            backgroundColor: Colors.blue[600],
            child: const Text(
              'Request',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Add Friends',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search by name or phone number',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              
              // Search Field
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or phone number...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: _searchUsers,
              ),
              const SizedBox(height: 16),
              
              // Search Results
              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                        ? _searchController.text.isNotEmpty
                            ? Center(
                                child: Text(
                                  'No users found',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  'Start typing to search for friends',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.grey[300],
                                      backgroundImage: user['photoUrl'] != null && user['photoUrl'].isNotEmpty
                                          ? NetworkImage(user['photoUrl'])
                                          : null,
                                      child: user['photoUrl'] == null || user['photoUrl'].isEmpty
                                          ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user['name'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          if (user['phoneNumber'] != null)
                                            Text(
                                              user['phoneNumber'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    _buildRelationshipWidget(user),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}