import 'package:flutter/material.dart';
import 'detailed_mechanic_card.dart';
import 'widgets/bottom_navbar.dart';
import 'services/find_mechanic_service.dart';
import 'location_service.dart';

class FindMechanicsPage extends StatefulWidget {
  const FindMechanicsPage({super.key});

  @override
  State<FindMechanicsPage> createState() => _FindMechanicsPageState();
}

class _FindMechanicsPageState extends State<FindMechanicsPage> {
  List<Map<String, dynamic>> mechanics = [];
  bool isLoading = true;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMechanics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMechanics() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Try to get user's current location (optional now)
      double? userLat;
      double? userLng;
      
      try {
        final locationString = await LocationService.getCurrentLocation(context);
        if (locationString != null) {
          final locationParts = locationString.split(', ');
          userLat = double.tryParse(locationParts[0]);
          userLng = double.tryParse(locationParts[1]);
        }
      } catch (e) {
        // Continue without location - we'll show all mechanics
      }

      // Fetch all registered mechanics from database
      final fetchedMechanics = await FindMechanicService.fetchAllMechanics(
        userLat: userLat,
        userLng: userLng,
        searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
      );
      
      setState(() {
        mechanics = fetchedMechanics;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading mechanics: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _performSearch() async {
    setState(() {
      searchQuery = _searchController.text;
    });
    await _loadMechanics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Mechanics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMechanics,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by name or service',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _performSearch,
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 20),
            
            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1, // Find Mechanics tab index
        onTap: (index) {
          if (index == 1) return; // Already on Find Mechanics
          switch (index) {
            case 0:
              // Navigate to home with fade transition
              Navigator.pushNamedAndRemoveUntil(context, '/userHome', (route) => false);
              break;
            case 2:
              // Navigate to messages
              Navigator.pushNamed(context, '/messages');
              break;
            case 3:
              // Navigate to history with slide transition
              Navigator.pushNamed(context, '/history');
              break;
            case 4:
              // Navigate to settings with slide transition
              Navigator.pushNamed(context, '/settings');
              break;
          }
        },
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading mechanics...'),
          ],
        ),
      );
    }

    if (mechanics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isEmpty 
                ? 'No mechanics found'
                : 'No mechanics found for "$searchQuery"',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isEmpty
                ? 'No mechanics are registered yet'
                : 'Try clearing the search filter',
              textAlign: TextAlign.center,
            ),
            if (searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    searchQuery = '';
                  });
                  _loadMechanics();
                },
                child: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${mechanics.length} mechanics found',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: mechanics.length,
            itemBuilder: (context, index) {
              return DetailedMechanicCard(mechanic: mechanics[index]);
            },
          ),
        ),
      ],
    );
  }
}
