import 'package:flutter/material.dart';
import '../models/users.dart';
import 'repository/user_repository.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final userRepo = UserRepository();
  List<Users> users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    await userRepo.openZone();
    final result = await userRepo.getAllUsers();
    setState(() => users = result);
  }

  Future<void> _addUser() async {
    final newUser = Users(
      uid: DateTime.now().millisecondsSinceEpoch.toString(),
      username: 'New User',
      district: 'Downtown',
    );
    
    final success = await userRepo.upsertUser(newUser);
    if (success) {
      _loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User added successfully')),
      );
    }
  }

  Future<void> _deleteUser(Users user) async {
    final success = await userRepo.deleteUser(user);
    if (success) {
      _loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User deleted successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Management')),
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, i) {
          final user = users[i];
          return ListTile(
            title: Text(user.username ?? 'Unknown'),
            subtitle: Text(user.district ?? 'N/A'),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _deleteUser(user),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addUser,
        child: Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    userRepo.closeZone();
    super.dispose();
  }
}