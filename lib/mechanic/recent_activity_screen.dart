import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mechfind/utils.dart';
import 'package:easy_localization/easy_localization.dart';

class RecentActivityScreen extends StatefulWidget {
  const RecentActivityScreen({super.key});

  @override
  State<RecentActivityScreen> createState() => _RecentActivityScreenState();
}

class _RecentActivityScreenState extends State<RecentActivityScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> recentActivities = [];
  bool isLoadingActivities = true;

  @override
  void initState() {
    super.initState();
    _fetchRecentActivities();
  }

  Future<void> _fetchRecentActivities() async {
    try {
      setState(() {
        isLoadingActivities = true;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          isLoadingActivities = false;
        });
        return;
      }

      final response = await supabase
          .from('requests')
          .select('''
            id,
            request_type,
            description,
            created_at,
            vehicle,
            status,
            user_id,
            guest_id,
            users(full_name, phone, image_url)
          ''')
          .eq('mechanic_id', user.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(20);

      // Process response to add customer name
      final List<Map<String, dynamic>> processedActivities = [];
      for (var activity in response) {
        final Map<String, dynamic> processedActivity = Map<String, dynamic>.from(activity);
        
        // Extract customer info from users join
        if (activity['users'] != null) {
          processedActivity['customer_name'] = activity['users']['full_name'] ?? 'Unknown';
          processedActivity['customer_phone'] = activity['users']['phone'] ?? '';
          processedActivity['customer_image'] = activity['users']['image_url'] ?? '';
        } else {
          processedActivity['customer_name'] = 'Unknown Customer';
          processedActivity['customer_phone'] = '';
          processedActivity['customer_image'] = '';
        }
        
        processedActivities.add(processedActivity);
      }

      setState(() {
        recentActivities = processedActivities;
        isLoadingActivities = false;
      });

    } catch (e) {
      print('Error fetching recent activities: $e');
      setState(() {
        isLoadingActivities = false;
      });
      _showBanner('Failed to load recent activities');
    }
  }

  void _showBanner(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'engine repair':
        return Icons.build_circle_outlined;
      case 'tire service':
        return Icons.circle_outlined;
      case 'battery service':
        return Icons.battery_charging_full_outlined;
      case 'brake repair':
        return Icons.disc_full_outlined;
      case 'oil change':
        return Icons.oil_barrel_outlined;
      case 'transmission repair':
        return Icons.settings_outlined;
      case 'ac repair':
        return Icons.ac_unit_outlined;
      case 'electrical repair':
        return Icons.electrical_services_outlined;
      case 'towing':
        return Icons.local_shipping_outlined;
      case 'jumpstart':
        return Icons.flash_on_outlined;
      default:
        return Icons.build_outlined;
    }
  }

  String _formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      final DateFormat formatter = DateFormat('MMM dd, yyyy • hh:mm a');
      return formatter.format(date);
    } catch (e) {
      return 'Date not available';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnglish = Localizations.localeOf(context).languageCode == 'en';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEnglish ? 'Recent Activity' : 'সাম্প্রতিক কার্যকলাপ',
          style: AppTextStyles.heading.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRecentActivities,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.05),
                Colors.white,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: isLoadingActivities
              ? const Center(child: CircularProgressIndicator())
              : recentActivities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_outlined,
                            size: 80,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isEnglish ? 'No recent activities' : 'কোন সাম্প্রতিক কার্যকলাপ নেই',
                            style: AppTextStyles.heading.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isEnglish ? 'Completed emergency jobs will appear here' : 'সম্পূর্ণ জরুরি কাজ এখানে দেখানো হবে',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: recentActivities.length,
                      itemBuilder: (context, index) {
                        final activity = recentActivities[index];
                        return _buildActivityCard(activity, isEnglish);
                      },
                    ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity, bool isEnglish) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.green.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.green,
                      Colors.lightGreen,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getServiceIcon(activity['request_type'] ?? ''),
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isEnglish ? 'Emergency' : 'জরুরি'} - ${activity['request_type'] ?? 'Service'}',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: FontSizes.body,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${isEnglish ? 'Customer:' : 'গ্রাহক:'} ${activity['customer_name'] ?? 'Unknown'}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: FontSizes.caption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isEnglish ? 'Completed' : 'সম্পূর্ণ',
                      style: AppTextStyles.body.copyWith(
                        fontSize: FontSizes.caption,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Date
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(activity['created_at'] ?? ''),
                style: AppTextStyles.body.copyWith(
                  fontSize: FontSizes.caption,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          
          if (activity['description'] != null && activity['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              activity['description'],
              style: AppTextStyles.body.copyWith(
                fontSize: FontSizes.caption,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          
          if (activity['vehicle'] != null && activity['vehicle'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isEnglish ? 'Vehicle:' : 'গাড়ি:'} ${activity['vehicle']}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: FontSizes.caption,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
