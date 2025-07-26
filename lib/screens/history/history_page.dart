import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/service_history.dart';
import '../rating/rate_mechanic_screen.dart';
import '../../widgets/bottom_navbar.dart';
import 'package:mechfind/utils.dart';

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
    _serviceHistory = [
      ServiceHistory(
        id: '1',
        mechanicId: 'mech_1',
        mechanicName: 'AutoCare Plus',
        serviceName: 'Engine Repair',
        serviceDate: DateTime.now().subtract(const Duration(days: 5)),
        status: 'completed',
        cost: 12500.0,
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
        cost: 4200.0,
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
        cost: 8500.0,
        description: 'Brake pad replacement',
        rating: 0.0,
        userReview: '',
        mechanicLocation: '789 Pine Rd, Uptown',
      ),
    ];
  }

  List<ServiceHistory> get filteredHistory {
    if (_selectedFilter == 'All') return _serviceHistory;
    return _serviceHistory
        .where((history) => history.status == _selectedFilter.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Service History',
          style: TextStyle(
            fontFamily: AppFonts.primaryFont,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
                context, '/userHome', (route) => false);
          },
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
          ),
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
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        onTap: (index) {
          if (index == 3) return;
          switch (index) {
            case 0:
              Navigator.pushNamedAndRemoveUntil(
                  context, '/userHome', (route) => false);
              break;
            case 1:
              Navigator.pushNamed(context, '/find-mechanics');
              break;
            case 2:
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Messages feature coming soon'),
              ));
              break;
            case 4:
              Navigator.pushNamed(context, '/settings');
              break;
          }
        },
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(
        filter,
        style: TextStyle(
          fontFamily: AppFonts.primaryFont,
          fontSize: FontSizes.body,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      backgroundColor: AppColors.background,
      selectedColor: AppColors.primary,
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
                        style: AppTextStyles.heading.copyWith(
                          fontSize: FontSizes.subHeading,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        history.serviceName,
                        style: AppTextStyles.label,
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
                const Icon(Icons.calendar_today,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(history.serviceDate),
                  style: AppTextStyles.label,
                ),
                const SizedBox(width: 16),
                const Icon(Icons.location_on,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    history.mechanicLocation,
                    style: AppTextStyles.label,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              history.description,
              style: AppTextStyles.body.copyWith(fontSize: FontSizes.body),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '৳${history.cost.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontFamily: AppFonts.primaryFont,
                    fontSize: FontSizes.subHeading,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                if (history.status == 'completed' && history.rating == 0.0)
                  ElevatedButton(
                    onPressed: () => _rateService(history),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Rate Service'),
                  )
                else if (history.rating > 0.0)
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (index) => Icon(
                          index < history.rating
                              ? Icons.star
                              : Icons.star_border,
                          size: 16,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        history.rating.toString(),
                        style: AppTextStyles.label,
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
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Review:',
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      history.userReview,
                      style: AppTextStyles.body,
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
          fontFamily: AppFonts.primaryFont,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No service history found',
            style: TextStyle(
              fontSize: FontSizes.subHeading,
              fontFamily: AppFonts.primaryFont,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your service history will appear here',
            style: TextStyle(
              fontSize: FontSizes.body,
              fontFamily: AppFonts.primaryFont,
              color: AppColors.textSecondary,
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
              final index =
                  _serviceHistory.indexWhere((h) => h.id == history.id);
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
