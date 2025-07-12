import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/service_history.dart';
import '../rating/rate_mechanic_screen.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<ServiceHistory> _serviceHistory = [];
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadServiceHistory();
  }

  void _loadServiceHistory() {
    // Mock service history data
    _serviceHistory = [
      ServiceHistory(
        id: '1',
        mechanicId: 'mech_1',
        mechanicName: 'AutoCare Plus',
        serviceName: 'Engine Repair',
        serviceDate: DateTime.now().subtract(const Duration(days: 5)),
        status: 'completed',
        cost: 150.0,
        description: 'Fixed engine overheating issue',
        rating: 4.5,
        userReview: 'Great service, very professional',
        mechanicLocation: '123 Main St, Downtown',
      ),
      ServiceHistory(
        id: '2',
        mechanicId: 'mech_2',
        mechanicName: 'QuickFix Motors',
        serviceName: 'Tire Change',
        serviceDate: DateTime.now().subtract(const Duration(days: 12)),
        status: 'completed',
        cost: 80.0,
        description: 'Replaced flat tire',
        rating: 5.0,
        userReview: 'Quick and efficient service',
        mechanicLocation: '456 Oak Ave, Midtown',
      ),
      ServiceHistory(
        id: '3',
        mechanicId: 'mech_3',
        mechanicName: 'Elite Auto Workshop',
        serviceName: 'Brake Service',
        serviceDate: DateTime.now().subtract(const Duration(days: 30)),
        status: 'completed',
        cost: 200.0,
        description: 'Brake pad replacement',
        rating: 0.0, // Not rated yet
        userReview: '',
        mechanicLocation: '789 Pine Rd, Uptown',
      ),
    ];
  }

  List<ServiceHistory> get filteredHistory {
    if (_selectedFilter == 'All') {
      return _serviceHistory;
    }
    return _serviceHistory.where((history) => history.status == _selectedFilter.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service History'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed'),
                const SizedBox(width: 8),
                _buildFilterChip('Ongoing'),
                const SizedBox(width: 8),
                _buildFilterChip('Cancelled'),
              ],
            ),
          ),
          
          // History List
          Expanded(
            child: filteredHistory.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final history = filteredHistory[index];
                      return _buildHistoryCard(history);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(filter),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: const Color(0xFF0D47A1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildHistoryCard(ServiceHistory history) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        history.mechanicName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        history.serviceName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(history.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(history.serviceDate),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    history.mechanicLocation,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              history.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '\$${history.cost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const Spacer(),
                if (history.status == 'completed' && history.rating == 0.0)
                  ElevatedButton(
                    onPressed: () => _rateService(history),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Rate Service'),
                  )
                else if (history.rating > 0.0)
                  Row(
                    children: [
                      ...List.generate(5, (index) => Icon(
                        index < history.rating ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      )),
                      const SizedBox(width: 8),
                      Text(
                        history.rating.toString(),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
              ],
            ),
            if (history.userReview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Review:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      history.userReview,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
        break;
      case 'ongoing':
        color = Colors.blue;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No service history found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your service history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _rateService(ServiceHistory history) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RateMechanicScreen(
          mechanicId: history.mechanicId,
          mechanicName: history.mechanicName,
          serviceId: history.id,
          onRatingSubmitted: (rating, review) {
            setState(() {
              final index = _serviceHistory.indexWhere((h) => h.id == history.id);
              if (index != -1) {
                _serviceHistory[index] = ServiceHistory(
                  id: history.id,
                  mechanicId: history.mechanicId,
                  mechanicName: history.mechanicName,
                  serviceName: history.serviceName,
                  serviceDate: history.serviceDate,
                  status: history.status,
                  cost: history.cost,
                  description: history.description,
                  rating: rating,
                  userReview: review,
                  mechanicLocation: history.mechanicLocation,
                );
              }
            });
          },
        ),
      ),
    );
  }
}
