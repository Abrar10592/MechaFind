import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mechfind/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mechfind/mechanic/chat_screen.dart';

class UpcomingJobsScreen extends StatefulWidget {
  const UpcomingJobsScreen({super.key});

  @override
  State<UpcomingJobsScreen> createState() => _UpcomingJobsScreenState();
}

class _UpcomingJobsScreenState extends State<UpcomingJobsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> upcomingJobs = [];
  bool isLoadingJobs = true;
  bool isProcessingJob = false;

  @override
  void initState() {
    super.initState();
    _fetchUpcomingJobs();
  }

  Future<void> _fetchUpcomingJobs() async {
    try {
      setState(() {
        isLoadingJobs = true;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          isLoadingJobs = false;
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
            lat,
            lng,
            image,
            users(full_name, phone, image_url)
          ''')
          .eq('mechanic_id', user.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(10);

      // Process response to add customer name
      final List<Map<String, dynamic>> processedJobs = [];
      for (var job in response) {
        final Map<String, dynamic> processedJob = Map<String, dynamic>.from(job);
        
        // Extract customer info from users join
        if (job['users'] != null) {
          processedJob['customer_name'] = job['users']['full_name'] ?? 'Unknown';
          processedJob['customer_phone'] = job['users']['phone'] ?? '';
          processedJob['customer_image'] = job['users']['image_url'] ?? '';
        } else {
          processedJob['customer_name'] = 'Unknown Customer';
          processedJob['customer_phone'] = '';
          processedJob['customer_image'] = '';
        }
        
        processedJobs.add(processedJob);
      }

      setState(() {
        upcomingJobs = processedJobs;
        isLoadingJobs = false;
      });

    } catch (e) {
      print('Error fetching upcoming jobs: $e');
      setState(() {
        isLoadingJobs = false;
      });
      _showBanner('Failed to load upcoming jobs');
    }
  }

  Future<void> _acceptJob(String requestId) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Accept Job',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.primary,
          ),
        ),
        content: Text(
          'Are you sure you want to accept this job request?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Accept Job',
              style: AppTextStyles.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (isProcessingJob) return;

    try {
      setState(() {
        isProcessingJob = true;
      });
      
      _showBanner('Accepting job...');

      await supabase
          .from('requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);

      _showBanner('Job accepted successfully');
      await _fetchUpcomingJobs();
      
    } catch (e) {
      print('Error accepting job: $e');
      _showBanner('Failed to accept job');
    } finally {
      setState(() {
        isProcessingJob = false;
      });
    }
  }

  Future<void> _rejectJob(String requestId) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reject Job',
          style: AppTextStyles.heading.copyWith(
            color: Colors.red.shade600,
          ),
        ),
        content: Text(
          'Are you sure you want to reject this job request?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Reject Job',
              style: AppTextStyles.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (isProcessingJob) return;

    try {
      setState(() {
        isProcessingJob = true;
      });
      
      _showBanner('Rejecting job...');

      await supabase
          .from('requests')
          .update({
            'status': 'rejected',
            'mechanic_id': null,
          })
          .eq('id', requestId);

      _showBanner('Job rejected');
      await _fetchUpcomingJobs();
      
    } catch (e) {
      print('Error rejecting job: $e');
      _showBanner('Failed to reject job');
    } finally {
      setState(() {
        isProcessingJob = false;
      });
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _showBanner('Phone number not available');
      return;
    }
    
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showBanner('Cannot make phone call');
      }
    } catch (e) {
      print('Error making phone call: $e');
      _showBanner('Failed to make phone call');
    }
  }

  void _openChat(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          receiverId: job['user_id'],
          receiverName: job['customer_name'] ?? 'Customer',
          receiverImageUrl: job['customer_image'],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final bool isEnglish = Localizations.localeOf(context).languageCode == 'en';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEnglish ? 'Upcoming Jobs' : 'আসন্ন কাজ',
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
        onRefresh: _fetchUpcomingJobs,
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
          child: isLoadingJobs
              ? const Center(child: CircularProgressIndicator())
              : upcomingJobs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.work_outline,
                            size: 80,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isEnglish ? 'No upcoming jobs' : 'কোন আসন্ন কাজ নেই',
                            style: AppTextStyles.heading.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isEnglish ? 'New job requests will appear here' : 'নতুন কাজের অনুরোধ এখানে দেখানো হবে',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: upcomingJobs.length,
                      itemBuilder: (context, index) {
                        final job = upcomingJobs[index];
                        return _buildJobCard(job, isEnglish);
                      },
                    ),
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, bool isEnglish) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            AppColors.primary.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
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
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getServiceIcon(job['request_type'] ?? ''),
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
                      job['request_type'] ?? 'Service',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: FontSizes.body,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${isEnglish ? 'Customer:' : 'গ্রাহক:'} ${job['customer_name'] ?? 'Unknown'}',
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
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isEnglish ? 'Pending' : 'অপেক্ষমান',
                  style: AppTextStyles.body.copyWith(
                    fontSize: FontSizes.caption,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (job['description'] != null && job['description'].toString().isNotEmpty) ...[
            Text(
              job['description'],
              style: AppTextStyles.body.copyWith(
                fontSize: FontSizes.caption,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],
          
          if (job['vehicle'] != null && job['vehicle'].toString().isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isEnglish ? 'Vehicle:' : 'গাড়ি:'} ${job['vehicle']}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: FontSizes.caption,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          
          const SizedBox(height: 16),
          
          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                onPressed: () => _acceptJob(job['id']),
                icon: Icons.check_circle_outline,
                label: isEnglish ? 'Accept' : 'গ্রহণ',
                color: Colors.green,
              ),
              _buildActionButton(
                onPressed: () => _rejectJob(job['id']),
                icon: Icons.cancel_outlined,
                label: isEnglish ? 'Reject' : 'প্রত্যাখ্যান',
                color: Colors.red,
              ),
              _buildActionButton(
                onPressed: () => _makePhoneCall(job['customer_phone'] ?? ''),
                icon: Icons.phone,
                label: isEnglish ? 'Call' : 'কল',
                color: Colors.blue,
              ),
              _buildActionButton(
                onPressed: () => _openChat(job),
                icon: Icons.chat_bubble_outline,
                label: isEnglish ? 'Chat' : 'চ্যাট',
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: isProcessingJob ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withOpacity(0.1),
            foregroundColor: color,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: FontSizes.caption - 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
