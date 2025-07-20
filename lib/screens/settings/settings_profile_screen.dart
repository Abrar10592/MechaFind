import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:mechfind/utils.dart'; // <-- make sure this path is correct

class SettingsProfileScreen extends StatefulWidget {
  const SettingsProfileScreen({super.key});

  @override
  State<SettingsProfileScreen> createState() => _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends State<SettingsProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _vehicleController = TextEditingController();

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  DateTime? _selectedDate;
  List<String> _vehicleModels = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    _nameController.text = 'John Doe';
    _emailController.text = 'john.doe@example.com';
    _phoneController.text = '+1234567890';
    _addressController.text = '123 Main St, City, State';
    _emergencyContactController.text = '+1234567891';
    _selectedDate = DateTime(1990, 1, 1);
    _vehicleModels = ['Toyota Camry 2020', 'Honda Civic 2018'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile & Settings', style: TextStyle(fontSize: 22,color: AppColors.textlight)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Picture
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                              child: _profileImage == null ? const Icon(Icons.person, size: 60) : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary,
                                child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap to change profile picture',
                        style: AppTextStyles.label,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Personal Info
              _buildSectionCard(
                title: 'Personal Information',
                children: [
                  _buildInput(_nameController, 'Full Name', Icons.person),
                  _buildInput(_emailController, 'Email Address', Icons.email),
                  _buildInput(_phoneController, 'Phone Number', Icons.phone),
                  _buildInput(_addressController, 'Address', Icons.location_on, maxLines: 2),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      _selectedDate != null
                          ? 'Date of Birth: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Select Date of Birth',
                      style: AppTextStyles.body,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: _selectDate,
                  ),
                  _buildInput(_emergencyContactController, 'Emergency Contact', Icons.contact_emergency),
                ],
              ),

              const SizedBox(height: 16),

              // Vehicle Info
              _buildSectionCard(
                title: 'Vehicle Information',
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildInput(_vehicleController, 'Vehicle Model', Icons.directions_car)),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addVehicle,
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_vehicleModels.isNotEmpty)
                    ...[
                      Text('Your Vehicles:', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      ..._vehicleModels.map(
                        (vehicle) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.directions_car),
                            title: Text(vehicle, style: AppTextStyles.body),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _removeVehicle(vehicle),
                            ),
                          ),
                        ),
                      ),
                    ]
                ],
              ),

              const SizedBox(height: 16),

              // App Settings
              _buildSectionCard(
                title: 'App Settings',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Push Notifications', style: AppTextStyles.body),
                    subtitle: Text('Receive notifications about services', style: AppTextStyles.label),
                    value: true,
                    onChanged: (value) {},
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Location Services', style: AppTextStyles.body),
                    subtitle: Text('Allow app to access your location', style: AppTextStyles.label),
                    value: true,
                    onChanged: (value) {},
                  ),
                  _buildNavTile('Privacy Policy', Icons.privacy_tip),
                  _buildNavTile('Help & Support', Icons.help),
                  _buildNavTile('Logout', Icons.logout, onTap: _logout),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTextStyles.label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.heading),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(String title, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.body),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: onTap,
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  void _addVehicle() {
    if (_vehicleController.text.isNotEmpty) {
      setState(() {
        _vehicleModels.add(_vehicleController.text);
        _vehicleController.clear();
      });
    }
  }

  void _removeVehicle(String vehicle) {
    setState(() {
      _vehicleModels.remove(vehicle);
    });
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout', style: AppTextStyles.heading),
        content: Text('Are you sure you want to logout?', style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
