import 'package:flutter/material.dart';
import '../models/Users.dart';
import '../repository/user_repository.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final userRepo = UserRepository();
  List<Users> users = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      await userRepo.openZone();
      final result = await userRepo.getAllUsers();
      
      setState(() {
        users = result;
        isLoading = false;
      });
      
      print('Loaded ${users.length} users');
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    userRepo.closeZone();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text('Error: $errorMessage'),
            ElevatedButton(
              onPressed: _loadUsers,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (users.isEmpty) {
      return Center(child: Text('No users found'));
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, i) {
        final u = users[i];
        return ListTile(
          title: Text(u.username ?? "Unknown"),
          subtitle: Text("District: ${u.district ?? 'N/A'}"),
        );
      },
    );
  }
}